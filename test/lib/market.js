const Market = require("../../lib/Market.js");
const Offer = require('../../lib/Offer.js');
const OfferRepository = require('../../lib/OfferRepository.js');
const MarketRepository = require('../../lib/MarketRepository.js');
const MarketArtifacts = artifacts.require("./protocol/Market/Market.sol");
const MarketFactoryArtifacts = artifacts.require("./protocol/Market/MarketFactory.sol");
const OfferArtifacts = artifacts.require("./protocol/Market/Offer.sol");

contract('Market Interface', function(accounts) {
  var offerRepo, marketRepo, market;
  
  let testOffer = {
    name: 'AAA',
    origin: 'BBB',
    category: 'Fish',
    packageWeight: 200,
    pricePerUnit: 100,
    pricePerPackage: 20000,
    imageHash: 'QmVPMUYVooLw9XRgEWFnKZLyaZeWBM18EX7X3g6hrQBDqB',
    seller: accounts[0],
    requirementsAddress: accounts[1],
    validatorAddress: accounts[1],
    quality: '',
  };

  beforeEach(async ()=>{
    offerRepo = new OfferRepository(OfferArtifacts);
    marketRepo = new MarketRepository(MarketArtifacts, MarketFactoryArtifacts);
    market = await marketRepo.create();
  })

  it('should add and get offer', async () => {   
    await offerRepo.save(market.getAddress(), testOffer, [], '');

    var offers = await offerRepo.getAllFromMarket(market);
    delete offers[0].address;
    delete offers[0].measurementsAddress;
    
    assert.deepEqual(offers[0], testOffer);
  });

  it('should get contract from address', async () => {
    await offerRepo.save(market.getAddress(), testOffer, [], '');
    var market2 = await marketRepo.fromAddress(market.getAddress());

    var offers = await offerRepo.getAllFromMarket(market);
    var offers2 = await offerRepo.getAllFromMarket(market2);

    assert.deepEqual(offers, offers2);
  });

});
