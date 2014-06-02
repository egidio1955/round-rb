require 'spec_helper'

describe BitVault::Wallet, :vcr do
  let(:authed_client) { BitVault::Patchboard.authed_client(email: 'julian@bitvault.io', password: 'terrible_secret') }
  let(:wallet) { authed_client.user.applications[0].wallets[0] }
  let(:passphrase) { 'very insecure' }
  let(:primary_seed) { CoinOp::Crypto::PassphraseBox.decrypt(passphrase, wallet.resource.primary_private_seed) }

  describe '#unlock' do
    it 'populates the multiwallet' do
      wallet.unlock(passphrase)
      expect(wallet.multiwallet).to_not be_nil
      expect(wallet.multiwallet).to be_a_kind_of(CoinOp::Bit::MultiWallet)
    end

    it 'decrypts the wallet' do
      wallet.unlock(passphrase)
      expect(wallet.multiwallet.trees[:primary].to_serialized_address(:private)).to eql(primary_seed)
    end
  end

  describe '#accounts' do
    before(:each) { 
      wallet.resource.accounts.stub(:list).and_return([])
    }

    it 'returns an AccountCollection' do
      expect(wallet.accounts).to be_a_kind_of(BitVault::AccountCollection)
    end

    it 'only fetches once' do
      wallet.resource.accounts.should_receive(:list).once
      wallet.accounts
      wallet.accounts
    end
  end

  describe 'delegate methods' do
    it 'delegates name to resource' do
      wallet.resource.should_receive(:name)
      wallet.name
    end
  end
end