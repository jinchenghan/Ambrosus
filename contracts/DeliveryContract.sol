pragma solidity ^0.4.8;

import "./FoodToken.sol";

contract DeliveryContract is Assertive {

    address owner;

    bytes32 public name;

    bytes32 public code;

    uint escrowed_amount;

    enum Stages {
        New,
        HasAttributes,
        WaitingForParties,
        InProgress,
        Complete,
        Canceled,
        Reimbursed
    }

    struct Attribute {
      bytes32 identifer;
      int min;
      int max;
    }

    struct Measurement {
      bytes32 attribute_id;
      int value;
      bytes32 event_id;
      uint timestamp;
      uint block_timestamp;
      bytes32 farmer_id;
      bytes32 batch_id;
    }

    struct Party {
      address wallet;
      uint amount;
      bool has_accepted;
    }
    
    uint accepted_no;

    Stages public stage = Stages.New;
    bool public state_machine_is_active;

    Attribute [] public attributes;

    Measurement [] measurements;
    
    Party [] parties;
    uint party_no;

    FoodToken public foodToken;

    modifier onlyOwner {
        assert(msg.sender == owner);
        _;
    }
    
    modifier onlyStage(Stages desired_stage) {
      if(state_machine_is_active) {
        Stages current_stage = stage;
        if (current_stage != desired_stage) throw;
      }
      else
      {
        throw;
      }
		

        _;
    }

    function DeliveryContract(bytes32 _name, bytes32 _code, bool _state_machine, address _foodTokenAddress) {
        owner = msg.sender;
        name = _name;
        code = _code;
        foodToken = FoodToken(_foodTokenAddress);
        state_machine_is_active = _state_machine;
    }
    
    function enable_state_machine() onlyOwner
    {
      // It can only be turned on and not off once deployed for security reasons.
      // The only way to turn the state machine off is to deploy it with it off.
      state_machine_is_active = true;
    }

    function setAttributes(bytes32 [] _identifers, int [] _mins, int [] _maxs) onlyOwner onlyStage(Stages.New) {
      stage = Stages.HasAttributes;
      if (_identifers.length != _mins.length) throw;
      if (_identifers.length != _maxs.length) throw;
      for (uint i = 0; i < _identifers.length; i++) {
        attributes.push(Attribute(_identifers[i], _mins[i], _maxs[i]));
      }
    }

    function inviteParticipants(address [] _parties, uint [] _amounts) onlyOwner onlyStage(Stages.HasAttributes) returns (bool) {
				stage = Stages.WaitingForParties;
				escrowed_amount = sum(_amounts);
				for (uint i = 0; i < _parties.length; i++) {
					parties.push(Party(_parties[i], _amounts[i], false));
					party_no += 1;
				}

				return foodToken.transferFrom(owner, this, escrowed_amount);
    }
    
    function processInvite(uint party_index, bool response) onlyStage(Stages.WaitingForParties)
    {		
      // Party doesn't exist -- overflow.
      if(party_index + 1 > party_no)
      {
        throw;
      }

      // Is this the owner of the invite?
      if(msg.sender != parties[party_index].wallet)
      {
        throw;
      }

      // They've already accepted.
      if(parties[party_index].has_accepted)
      {
        throw;
      }

      // User has accepted.
      if(response)
      {
        parties[party_index].has_accepted = true;
        accepted_no += 1;

        // All accepted.
        if(accepted_no == party_no)
        {
        stage = Stages.InProgress;
        }
      }
      else
      {
        stage = Stages.Canceled;
      }
    }

    function approve() onlyOwner onlyStage(Stages.InProgress)  {
      for (uint i = 0; i < parties.length; i++) {
          foodToken.transfer(parties[i].wallet, parties[i].amount);
      }
      stage = Stages.Complete;
    }

    function reimburse() onlyOwner onlyStage(Stages.WaitingForParties) onlyStage(Stages.Canceled){		
      if (msg.sender != owner) throw;
      stage = Stages.Reimbursed;
      uint amount = escrowed_amount;
      escrowed_amount = 0;
      foodToken.transfer(owner, amount);
    }

    function addMeasurements(bytes32 [] _events, bytes32 [] _attributes, int [] _values, uint [] _timestamps, bytes32 [] _farmer_codes, bytes32 [] _batch_nos) {
        if (_events.length != _attributes.length) throw;
        if (_events.length != _values.length) throw;
        if (_events.length != _timestamps.length) throw;
        if (_events.length != _farmer_codes.length) throw;
        if (_events.length != _batch_nos.length) throw;
        for (uint i = 0; i < _events.length; i++) {
            measurements.push(Measurement(_attributes[i], _values[i], _events[i], _timestamps[i], now, _farmer_codes[i], _batch_nos[i]));
        }
    }

    function getAttributes() constant returns (bytes32 [], int [], int []) {
        bytes32 [] memory identifers = new bytes32[](attributes.length);
        int [] memory mins = new int[](attributes.length);
        int [] memory maxs = new int[](attributes.length);
        for (uint i = 0; i < attributes.length; i++) {
          identifers[i] = attributes[i].identifer;
          mins[i] = attributes[i].min;
          maxs[i] = attributes[i].max;
        }
        return (identifers, mins, maxs);
    }

    function getMeasurements() constant returns (bytes32 [], bytes32 [], int [], uint [], uint [], bytes32 [], bytes32 []) {
        bytes32 [] memory attribute_ids = new bytes32[](measurements.length);
        int [] memory values = new int[](measurements.length);
        bytes32 [] memory event_ids = new bytes32[](measurements.length);
        uint [] memory timestamps = new uint[](measurements.length);
        uint [] memory block_timestamps = new uint[](measurements.length);
        bytes32 [] memory farmer_ids = new bytes32[](measurements.length);
        bytes32 [] memory batch_ids = new bytes32[](measurements.length);
        for (uint i = 0; i < measurements.length; i++) {
          attribute_ids[i] = measurements[i].attribute_id;
          values[i] = measurements[i].value;
          event_ids[i] = measurements[i].event_id;
          timestamps[i] = measurements[i].timestamp;
          block_timestamps[i] = measurements[i].block_timestamp;
          farmer_ids[i] = measurements[i].farmer_id;
          batch_ids[i] = measurements[i].batch_id;
        }
        return (event_ids, attribute_ids, values, timestamps, block_timestamps, farmer_ids, batch_ids);
    }

    function getParticipants() constant returns (address [], uint []) {
        address [] memory wallets = new address[](parties.length);
        uint [] memory amounts = new uint[](parties.length);
        for (uint i = 0; i < parties.length; i++) {
          wallets[i] = parties[i].wallet;
          amounts[i] = parties[i].amount;
        }
        return (wallets, amounts);
    }

    function sum(uint[] memory self) internal constant returns (uint r) {
      r = self[0];
      for (uint i = 1; i < self.length; i++) {
        r += self[i];
      }
    }

}
