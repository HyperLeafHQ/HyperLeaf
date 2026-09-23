use crate::*;

#[derive(Accounts)]
pub struct Halt<'info> {
    #[account(address = store.admin @ LeafJitoError::Unauthorized)]
    pub admin: Signer<'info>,
    #[account(mut, seeds = [STORE_SEED], bump = store.bump)]
    pub store: Account<'info, Store>,
}

impl Halt<'_> {
    pub fn apply(ctx: &mut Context<Halt>) -> Result<()> {
        let mut box_ = ctx.accounts.store.lockbox();
        box_.halt();
        ctx.accounts.store.apply_lockbox(&box_);
        Ok(())
    }
}
