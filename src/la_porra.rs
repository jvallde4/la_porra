#![no_std]

#[allow(unused_imports)]
use multiversx_sc::imports::*;
multiversx_sc::derive_imports!();

/// Informació d'una aposta.
#[type_abi]
#[derive(TopEncode, TopDecode, NestedEncode, NestedDecode, PartialEq, Eq)]
pub struct Bet<M: ManagedTypeApi> {
    /// Gols de l'equip local.
    home_score: u8,
    /// Gols de l'equip visitant.
    away_score: u8,
    amount: BigUint<M>,
    claimed: bool,
}

/// Contract d'apostes amb data límit fixa.
///
/// - Accepta apostes fins a una data límit.
/// - Cada participant pot fer fins a 10 apostes, però cada aposta ha de ser única
///   (no es pot repetir la mateixa combinació de resultat).
/// - Desa el total recaptat i les apostes de cada participant.
/// - Un cop passada la data límit, l'owner crida `resolveBets` indicant
///   el resultat guanyador. Si hi ha guanyadors, el contracte reparteix el total recaptat
///   proporcionalment entre els que han encertat. Si no hi ha guanyadors, tot el pot
///   s'envia a l'owner.
#[multiversx_sc::contract]
pub trait LAPorra {

    /// Inicialització del contracte.
    ///
    /// `deadline_timestamp` és un timestamp UNIX (segons) que representa la data límit
    /// per fer apostes (per exemple el 25/12/2025 a una hora concreta).
    /// `bet_price` és el cost fix d'una aposta i només el pot modificar l'owner.
    #[init]
    fn init(&self, deadline_timestamp: u64, bet_price: BigUint) {
        let caller = self.blockchain().get_caller();
        self.owner().set(&caller);
        self.deadline().set(deadline_timestamp);
        require!(bet_price > BigUint::zero(), "Bet price must be > 0");
        self.bet_price().set(bet_price);
        self.total_pot().set(BigUint::zero());
        self.resolved().set(false);
    }

    #[upgrade]
    fn upgrade(&self) {}

    ////////////////////////////////////////////////////////////////////////////////
    //                                    VIEWS
    ////////////////////////////////////////////////////////////////////////////////

    /// Owner del contracte (qui pot resoldre les apostes).
    #[view(getOwner)]
    #[storage_mapper("owner")]
    fn owner(&self) -> SingleValueMapper<ManagedAddress>;

    /// Data límit per acceptar apostes.
    #[view(getDeadline)]
    #[storage_mapper("deadline")]
    fn deadline(&self) -> SingleValueMapper<u64>;

    /// Total recaptat en el pot.
    #[view(getTotalPot)]
    #[storage_mapper("total_pot")]
    fn total_pot(&self) -> SingleValueMapper<BigUint>;

    /// Preu fix de cada aposta.
    #[view(getBetPrice)]
    #[storage_mapper("bet_price")]
    fn bet_price(&self) -> SingleValueMapper<BigUint>;

    /// Resultat guanyador (gols local, gols visitant), si ja s'ha resolt.
    #[view(getWinningResult)]
    #[storage_mapper("winning_result")]
    fn winning_result(&self) -> SingleValueMapper<(u8, u8)>;

    /// Indica si el contracte ja ha estat resolt.
    #[view(isResolved)]
    #[storage_mapper("resolved")]
    fn resolved(&self) -> SingleValueMapper<bool>;

    /// Apostes d'un participant concret (fins a 10).
    #[view(getBets)]
    fn get_bets(&self, addr: ManagedAddress) -> MultiValueEncoded<Bet<Self::Api>> {
        self.bets(&addr).iter().collect()
    }

    #[storage_mapper("bets")]
    fn bets(&self, addr: &ManagedAddress) -> VecMapper<Bet<Self::Api>>;

    /// Conjunt de tots els participants que han apostat.
    #[storage_mapper("bettors")]
    fn bettors(&self) -> UnorderedSetMapper<ManagedAddress>;

    /// Retorna l'identificador (adreça) del contracte desplegat.
    #[view(getContractAddress)]
    fn get_contract_address(&self) -> ManagedAddress {
        self.blockchain().get_sc_address()
    }

    ////////////////////////////////////////////////////////////////////////////////
    //                                 ENDPOINTS
    ////////////////////////////////////////////////////////////////////////////////

    /// Fer una aposta indicant un resultat (gols local - gols visitant) i enviant EGLD.
    ///
    /// - Només es pot cridar abans de la data límit.
    /// - Cada adreça pot tenir fins a 10 apostes.
    /// - Cada aposta ha de ser única (no es pot repetir la mateixa combinació de resultat).
    #[payable("EGLD")]
    #[endpoint(placeBet)]
    fn place_bet(&self, home_score: u8, away_score: u8) {
        let now = self.blockchain().get_block_timestamp();
        let deadline = self.deadline().get();
        require!(now < deadline, "Betting period is over");

        let caller = self.blockchain().get_caller();

        // Import apostat
        let payment = self.call_value().egld().clone_value();
        let zero = BigUint::zero();
        require!(payment > zero, "Bet amount must be > 0");
        let price = self.bet_price().get();
        require!(payment == price, "Must send exact bet price");

        // Assegurem que l'usuari no supera les 10 apostes.
        let mut bet_vec = self.bets(&caller);
        let bet_count = bet_vec.len();
        require!(bet_count < 10usize, "Maximum 10 bets per address");

        // Comprovem que aquesta combinació de resultat no existeixi ja.
        for existing_bet in bet_vec.iter() {
            require!(
                existing_bet.home_score != home_score || existing_bet.away_score != away_score,
                "You already have a bet with this result"
            );
        }

        let bet = Bet::<Self::Api> {
            home_score,
            away_score,
            amount: payment.clone(),
            claimed: false,
        };
        bet_vec.push(&bet);

        // Actualitzem la llista de participants i el pot total.
        self.bettors().insert(caller);

        let mut pot = self.total_pot().get();
        pot += &payment;
        self.total_pot().set(pot);
    }

    /// Resolució de les apostes un cop passada la data límit.
    ///
    /// - Només la pot cridar l'owner.
    /// - Només es pot cridar un cop.
    /// - `home_score` i `away_score` són el resultat correcte.
    /// - Si hi ha guanyadors, el pot es reparteix proporcionalment a l'import apostat
    ///   entre tots els que han encertat.
    /// - Si no hi ha guanyadors, tot el pot s'envia a l'owner.
    #[only_owner]
    #[endpoint(resolveBets)]
    fn resolve_bets(&self, home_score: u8, away_score: u8) {
        require!(!self.resolved().get(), "Already resolved");

        let now = self.blockchain().get_block_timestamp();
        let deadline = self.deadline().get();
        require!(now >= deadline, "Too early to resolve");

        // Calculem el total apostat pels que han encertat.
        let mut total_winning_amount = BigUint::zero();
        for addr in self.bettors().iter() {
            let bets_for_addr = self.bets(&addr);
            for bet in bets_for_addr.iter() {
                if bet.home_score == home_score && bet.away_score == away_score {
                    total_winning_amount += &bet.amount;
                }
            }
        }

        let zero = BigUint::zero();
        let total_pot = self.total_pot().get();

        if total_winning_amount > zero {
            // Hi ha guanyadors: repartim el pot proporcionalment.
            for addr in self.bettors().iter() {
                let mut bets_for_addr = self.bets(&addr);
                let len = bets_for_addr.len();
                for i in 0..len {
                    let mut bet = bets_for_addr.get(i);
                    if bet.home_score == home_score && bet.away_score == away_score && !bet.claimed {
                        let share = &bet.amount * &total_pot / &total_winning_amount;
                        if share > zero {
                            self.send().direct_egld(&addr, &share);
                        }
                        bet.claimed = true;
                        bets_for_addr.set(i, &bet);
                    }
                }
            }
        } else {
            // No hi ha guanyadors: tot el pot va a l'owner.
            if total_pot > zero {
                let owner = self.owner().get();
                self.send().direct_egld(&owner, &total_pot);
            }
        }

        self.winning_result().set((home_score, away_score));
        self.resolved().set(true);
    }
}
