// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {NFTMarket} from "./NFTMarket.sol";

contract NFTMarketPerimit is NFTMarket, Ownable, EIP712 {
    mapping(address => bool) public whiteList;
    string private constant SIGNING_DOMAIN = "NFT-Market";
    string private constant SIGNATURE_VERSION = "1";
    bytes32 private constant WHITE_LIST_TYPE_HASH =
        keccak256(
            "WhiteList(address signer,address user,uint256 nonce,uint256 deadline)"
        );
    constructor()
        Ownable(msg.sender)
        EIP712(SIGNING_DOMAIN, SIGNATURE_VERSION)
    {}

    function addWhiteList(address user) public onlyOwner {
        if (!whiteList[user]) {
            whiteList[user] = true;
        }
    }

    function removeWhiteList(address user) public onlyOwner {
        if (whiteList[user]) {
            delete whiteList[user];
        }
    }

    function listPermit(bytes memory erc721Signature) public {}

    function permitBuy(IERC721 nft,uint256 tokenId,){
        
    }
}
