// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
import {IERC20, ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {MyNFT} from "../ERC721/MyNFT.sol";
interface INFTMarketEvents {
    event NFTListed(
        address indexed nftAddress,
        uint256 indexed tokenId,
        address seller,
        uint256 price,
        address token
    );
    event NFTBought(
        address indexed buyer,
        address indexed nftAddress,
        uint256 indexed tokenId,
        uint256 price
    );
    event NFTDelisted(
        address indexed seller,
        address indexed nftAddress,
        uint256 indexed tokenId
    );
}

interface INFTMarketErrors {
    error PaymentFailed(address buyer, address seller, uint256 price);
    error NotListedForSale(uint256 tokenId);
    error NotAllowed(address buyer, address seller, uint256 tokenId);
}

contract NFTMarket is INFTMarketEvents, INFTMarketErrors {
    struct Listing {
        address seller;
        address token;
        uint256 price;
    }

    mapping(address nftToken => mapping(uint256 tokenId => Listing))
        public userNFTListing;

    constructor() {}

    //list(transfer) nft from owner to market
    function list(
        IERC721 nft,
        uint256 tokenId,
        address token,
        uint256 price
    ) public {
        nft.safeTransferFrom(
            msg.sender,
            address(this),
            tokenId,
            abi.encode(token, price) //作为data 在回调时使用
        );
        emit NFTListed(address(nft), tokenId, msg.sender, price, token);
    }

    function buy(address nft, uint256 tokenId) public returns (bool) {
        Listing memory listing = userNFTListing[nft][tokenId];

        //是否在listing中
        if (listing.seller == address(0)) {
            revert NotListedForSale(tokenId);
        }
        //买方和卖方是否是同一个人
        if (listing.seller == msg.sender) {
            revert NotAllowed(listing.seller, msg.sender, tokenId);
        }

        delete userNFTListing[nft][tokenId];

        if (
            !IERC20(listing.token).transferFrom(
                msg.sender,
                listing.seller,
                listing.price
            )
        ) {
            revert PaymentFailed(msg.sender, listing.seller, listing.price);
        }

        IERC721(nft).transferFrom(listing.seller, msg.sender, tokenId);

        return true;
    }

    function onERC721Received(
        address /*operator*/,
        address from, //seller
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4) {
        address nft = msg.sender;
        require(nft.code.length > 0, "listing is only for contract");

        (address token, uint256 price) = abi.decode(data, (address, uint256));

        userNFTListing[nft][tokenId] = Listing(from, token, price);

        return this.onERC721Received.selector;
    }

    function getTokenSellInfo(
        address nft,
        uint256 tokenId
    ) public view returns (address, address, uint256) {
        return (
            userNFTListing[nft][tokenId].seller,
            userNFTListing[nft][tokenId].token,
            userNFTListing[nft][tokenId].price
        );
    }
}
