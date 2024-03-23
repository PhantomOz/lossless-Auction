// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LibDiamond} from "../libraries/LibDiamond.sol";
import {LibAppStorage} from "../libraries/LibAppStorage.sol";
import {IERC721} from "../interfaces/IERC721.sol";
import {IERC165} from "../interfaces/IERC165.sol";
import {IERC1155} from "../interfaces/IERC1155.sol";

error AuctionFacet__NotOwnerOfNFT();
error AuctionFacet__InvalidNFTContract();
error AuctionFacet__AlreadyHighestBidder();
error AuctionFacet__LesserBidAmount();
error AuctionFacet__AuctionEnded();
error AuctionFacet__NotEnoughBalanceTobid();
error AuctionFacet__UnprofitableBid();
error AuctionFacet__AuctionHasNotEnded();
error AuctionFacet__InvalidNFTType();
error AuctionFacet__OnlyHighestBidderCanClaim();
error AuctionFacet__NoPreviousBidder();
error AuctionFacet__NoLastInteractor();

contract AuctionFacet {
    LibAppStorage.Layout internal l;

    function createAuction(
        uint256 _duration,
        uint256 _startingBid,
        uint256 _nftId,
        address _nftAddress
    ) public {
        if (IERC165(_nftAddress).supportsInterface(type(IERC721).interfaceId)) {
            if (IERC721(_nftAddress).ownerOf(_nftId) != msg.sender)
                revert AuctionFacet__NotOwnerOfNFT();
        } else if (
            IERC165(_nftAddress).supportsInterface(type(IERC1155).interfaceId)
        ) {
            if (IERC1155(_nftAddress).balanceOf(msg.sender, _nftId) <= 0)
                revert AuctionFacet__NotOwnerOfNFT();
        } else {
            revert AuctionFacet__InvalidNFTContract();
        }
        uint256 auctionId = l.auctionCount + 1;
        LibAppStorage.AuctionDetails storage a = l.Auctions[auctionId];
        a.duration = _duration;
        a.startingBid = _startingBid;
        a.nftId = _nftId;
        a.nftAddress = _nftAddress;

        l.auctionCount = l.auctionCount + 1;
    }

    function bid(uint256 _amount, uint256 _auctionId) public {
        LibAppStorage.AuctionDetails storage a = l.Auctions[_auctionId];
        if (a.highestBidder == msg.sender)
            revert AuctionFacet__AlreadyHighestBidder();
        if (a.startingBid > _amount) revert AuctionFacet__LesserBidAmount();
        if (a.duration <= block.timestamp) revert AuctionFacet__AuctionEnded();

        uint256 balance = l.balances[msg.sender];
        if (balance < _amount) revert AuctionFacet__NotEnoughBalanceTobid();

        if (a.currentBid == 0) {
            LibAppStorage._transferFrom(msg.sender, address(this), _amount);
            a.highestBidder = msg.sender;
            a.currentBid = _amount;
        } else {
            uint256 check = ((a.currentBid * 20) / 100) + a.currentBid;
            if (_amount < check) {
                revert AuctionFacet__UnprofitableBid();
            }
            LibAppStorage._transferFrom(msg.sender, address(this), _amount);
            //_payPreviousBidder
            _payPreviousBidder(_auctionId, _amount, a.currentBid);

            a.previousBidder = a.highestBidder;
            a.highestBidder = msg.sender;
            a.currentBid = _amount;

            _handleTransactionCosts(_auctionId, _amount);
            payLastInteractor(_auctionId, a.highestBidder);
        }
    }

    function claimReward(uint256 _auctionId) public {
        LibAppStorage.AuctionDetails storage a = l.Auctions[_auctionId];
        if (a.highestBidder != msg.sender)
            revert AuctionFacet__OnlyHighestBidderCanClaim();
        if (a.duration > block.timestamp)
            revert AuctionFacet__AuctionHasNotEnded();

        if (
            IERC165(a.nftAddress).supportsInterface(type(IERC1155).interfaceId)
        ) {
            IERC1155(a.nftAddress).safeTransferFrom(
                address(this),
                msg.sender,
                a.nftId,
                1,
                ""
            );
        } else if (
            IERC165(a.nftAddress).supportsInterface(type(IERC721).interfaceId)
        ) {
            // Transfer ERC721 token to the winner
            IERC721(a.nftAddress).safeTransferFrom(
                address(this),
                msg.sender,
                a.nftId
            );
        } else {
            revert AuctionFacet__InvalidNFTType();
        }
        a.highestBidder = address(0);
        a.currentBid = 0;
        a.previousBidder = address(0);
        a.duration = 0;
        a.startingBid = 0;
        a.nftId = 0;
        a.nftAddress = address(0);
    }

    function _payPreviousBidder(
        uint256 _auctionId,
        uint256 _amount,
        uint256 _previousBid
    ) private {
        LibAppStorage.AuctionDetails storage a = l.Auctions[_auctionId];
        if (a.previousBidder == address(0))
            revert AuctionFacet__NoPreviousBidder();

        uint256 paymentAmount = ((_amount * LibAppStorage.PreviousBidder) /
            100) + _previousBid;
        LibAppStorage._transferFrom(
            address(this),
            a.previousBidder,
            paymentAmount
        );
    }

    function _handleTransactionCosts(
        uint256 _auctionId,
        uint256 _amount
    ) private {
        LibAppStorage.AuctionDetails storage a = l.Auctions[_auctionId];
        uint256 burnAmount = (_amount * LibAppStorage.Burnable) / 100;
        LibAppStorage._transferFrom(
            address(this),
            a.previousBidder,
            burnAmount
        );

        uint256 daoAmount = (_amount * LibAppStorage.DAO) / 100;
        LibAppStorage._transferFrom(
            address(this),
            LibAppStorage.DAOAddress,
            daoAmount
        );

        uint256 teamAmount = (_amount * LibAppStorage.TeamWallet) / 100;
        LibAppStorage._transferFrom(
            address(this),
            LibAppStorage.TeamWalletAddress,
            teamAmount
        );
    }
    function payLastInteractor(
        uint256 _auctionId,
        address _lastInteractor
    ) private {
        LibAppStorage.AuctionDetails storage a = l.Auctions[_auctionId];
        if (_lastInteractor == address(0))
            revert AuctionFacet__NoLastInteractor();

        uint256 paymentAmount = (a.currentBid * 1) / 100;
        LibAppStorage._transferFrom(
            address(this),
            _lastInteractor,
            paymentAmount
        );
    }
}
