// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library LibAppStorage {
    uint256 constant FeePercentage = 10;
    uint256 constant Burnable = 2;
    uint256 constant DAO = 2;
    uint256 constant TeamWallet = 2;
    uint256 constant PreviousBidder = 3;
    uint256 constant Lastinteractor = 1;
    address constant TeamWalletAddress = 0x02F6302D1b7C94FF01a2B59ebAC8d9aa2fc62522;
    address constant DAOAddress = 0x02F6302D1b7C94FF01a2B59ebAC8d9aa2fc62522;

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    struct AuctionDetails {
        address highestBidder;
        address previousBidder;
        uint256 duration;
        uint256 startingBid;
        uint256 nftId;
        uint256 auctionId;
        address nftAddress;
        uint256 currentBid;
        // uint256 startTime;
    }
    struct Layout {
        //ERC20
        string name;
        string symbol;
        uint256 totalSupply;
        uint8 decimals;
        mapping(address => uint256) balances;
        mapping(address => mapping(address => uint256)) allowances;
        //Auction
        address AUCToken;
        mapping(uint => AuctionDetails) Auctions;
        uint256 auctionCount;
    }

    function layoutStorage() internal pure returns (Layout storage l) {
        assembly {
            l.slot := 0
        }
    }

    function _transferFrom(
        address _from,
        address _to,
        uint256 _amount
    ) internal {
        Layout storage l = layoutStorage();
        uint256 frombalances = l.balances[msg.sender];
        require(
            frombalances >= _amount,
            "ERC20: Not enough tokens to transfer"
        );
        l.balances[_from] = frombalances - _amount;
        l.balances[_to] += _amount;
        emit Transfer(_from, _to, _amount);
    }
}
