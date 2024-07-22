// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

interface IERC20Receiver {
    function onERC20Received(
        address operator,
        address from,
        uint256 value,
        bytes calldata data
    ) external returns (bytes4);
}

contract NFTMarket is ReentrancyGuard, Ownable, IERC20Receiver, EIP712 {
    using ECDSA for bytes32;
    struct Listing {
        uint256 price;
        address seller;
    }

    struct SellOrder {
        address nftContract;
        uint256 tokenId;
        uint256 price;
        address seller;
        uint256 deadline;
    }
    IERC20 public token;

    mapping(address => mapping(uint256 => Listing)) public listings;
    mapping(bytes32 => bool) public orders;

    event NFTListed(
        address indexed nftContract,
        uint256 indexed tokenId,
        uint256 price,
        address indexed seller
    );
    event NFTSold(
        address indexed nftContract,
        uint256 indexed tokenId,
        uint256 price,
        address indexed buyer
    );
    event Deposit(address indexed user, uint256 amount);

    bytes32 private constant SELL_ORDER_TYPEHASH =
        keccak256(
            "SellOrder(address nftContract,uint256 tokenId,uint256 price,address seller,uint256 deadline)"
        );

    constructor(
        address _tokenAddress
    ) EIP712("NFTMarket", "1") Ownable(msg.sender) {
        token = IERC20(_tokenAddress);
    }

    function list(
        address nftContract,
        uint256 tokenId,
        uint256 price
    ) external nonReentrant {
        IERC721 nft = IERC721(nftContract);
        require(nft.ownerOf(tokenId) == msg.sender, "You do not own this NFT");
        require(
            nft.isApprovedForAll(msg.sender, address(this)) ||
                nft.getApproved(tokenId) == address(this),
            "Marketplace not approved"
        );
        listings[nftContract][tokenId] = Listing(price, msg.sender);
        emit NFTListed(nftContract, tokenId, price, msg.sender);
    }

    function buyNFT(
        address nftContract,
        uint256 tokenId
    ) external nonReentrant {
        Listing memory listing = listings[nftContract][tokenId];
        require(listing.price > 0, "NFT not listed for sale");

        token.transferFrom(msg.sender, listing.seller, listing.price);
        IERC721(nftContract).safeTransferFrom(
            listing.seller,
            msg.sender,
            tokenId
        );

        emit NFTSold(nftContract, tokenId, listing.price, msg.sender);
    }

    function permitDeposit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external nonReentrant {
        ERC20Permit(address(token)).permit(
            owner,
            spender,
            value,
            deadline,
            v,
            r,
            s
        );
        token.transferFrom(owner, address(this), value);
        emit Deposit(owner, value);
    }

    function permitBuy(
        address nftContract,
        uint256 tokenId,
        uint256 price,
        uint256 deadline,
        bytes calldata signatureForWL,
        bytes calldata signatureForSellOrder,
        bytes calldata signatureForApprove,
        address buyer
    ) external nonReentrant {
        // 验证白名单签名
        verifyWhitelistSignature(buyer, deadline, signatureForWL);
        // 检查订单并处理购买
        handlePurchase(
            nftContract,
            tokenId,
            price,
            deadline,
            signatureForSellOrder,
            signatureForApprove,
            buyer
        );
    }

    function handlePurchase(
        address nftContract,
        uint256 tokenId,
        uint256 price,
        uint256 deadline,
        bytes calldata signatureForSellOrder,
        bytes calldata signatureForApprove,
        address buyer
    ) internal {
        Listing memory listing = listings[nftContract][tokenId];
        require(listing.price == price, "Incorrect price");

        bytes32 orderHash = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    SELL_ORDER_TYPEHASH,
                    nftContract,
                    tokenId,
                    price,
                    listing.seller,
                    deadline
                )
            )
        );
        require(
            getSigner(orderHash, signatureForSellOrder) == listing.seller,
            "Invalid sell order signature"
        );
        require(!orders[orderHash], "Order already filled");

        orders[orderHash] = true;

        // 处理 ERC20 授权
        ERC20Permit(address(token)).permit(
            buyer,
            address(this),
            price,
            deadline,
            uint8(signatureForApprove[64]),
            bytes32(signatureForApprove),
            bytes32(signatureForApprove[32:64])
        );

        token.transferFrom(buyer, listing.seller, price);
        IERC721(nftContract).safeTransferFrom(listing.seller, buyer, tokenId);

        delete listings[nftContract][tokenId];

        emit NFTSold(nftContract, tokenId, price, buyer);
    }
    function verifyWhitelistSignature(
        address buyer,
        uint256 deadline,
        bytes calldata signatureForWL
    ) internal view {
        bytes32 messageHash = keccak256(abi.encodePacked(buyer, deadline));
        bytes32 ethSignedMessageHash = _hashTypedDataV4(messageHash);
        require(
            getSigner(ethSignedMessageHash, signatureForWL) == owner(),
            "Invalid whitelist signature"
        );
    }

    function getSigner(
        bytes32 messageHash,
        bytes memory signature
    ) internal pure returns (address) {
        return messageHash.recover(signature);
    }
}
