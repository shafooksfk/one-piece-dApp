// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract OnePieceMint is VRFConsumerBasev2, ERC721, Ownable, ERC721URIStorage {
    uint256 private s_tokenCounter; // Used to keep track of the number of NFTs being minted
    VRFCoordinatorV2Interface private i_vrfCoordinator; // Used to store VRF coordinator link
    uint64 private i_subscriptionId; // Used to store subscription ID from VRF chainlink
    bytes32 private i_keyHash; // Used to store key hash from VRF chainlink
    uint32 private i_callbackGasLimit; // Used to specify the gas limit

    mapping(uint256 => address) private requestIdToSender; // allows the contract to keep track of which address made a request
    mapping(address => uint256) private userCharacter; // enables the contract to associate each user with their selected character
    mapping(address => bool) public hasMinted; // prevents users from minting multiple NFTs with the same address
    mapping(address => uint256) public s_addressToCharacter; // allows users to query which character they received based on their address

    event NftRequested(uint256 requestId, address requester);
    event CharacterTraitDetermined(uint256 characterId);
    event NftMinted(uint256 characterId, address minter);

    constructor(
        address vrfCoordinatorV2Address,
        uint64 subId,
        bytes32 keyHash,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinatorV2Address) ERC721("OnePiece NFT", "OPN") {
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2Address);
        i_subscriptionId = subId;
        i_keyHash = keyHash;
        i_callbackGasLimit = callbackGasLimit;
    }

    function mintNFT(address recipient, uint256 characterId) internal {
    // Ensure the address has not been minted before
    require(!hasMinted[recipient], "You have already minted your house NFT");

    // Get the next available token ID
    uint256 tokenId = s_tokenCounter;

    // Mint the NFT and assign it to the recipient
    _safeMint(recipient, tokenId);

    // Set the token URI for the minted NFT based on the character ID
    _setTokenURI(tokenId, characterTokenURIs[characterId]);

    // Map the recipient's address to the character ID they received
    s_addressToCharacter[recipient] = characterId;

    // Increment the token counter for the next minting
    s_tokenCounter += 1;

    // Mark the recipient's address as having minted an NFT
    hasMinted[recipient] = true;

    // Emit an event to log the minting of the NFT
    emit NftMinted(characterId, recipient);
}

function requestNFT(uint256[5] memory answers) public {
    // Determine the character based on the provided answers and store it for the user
    userCharacter[msg.sender] = determineCharacter(answers);

    // Request random words from the VRF coordinator to determine the character traits
    uint256 requestId = i_vrfCoordinator.requestRandomWords(
        i_keyHash, 
        i_subscriptionId,
        3,
        i_callbackGasLimit,
        1
    );

    // Map the request ID to the sender's address for later reference
    requestIdToSender[requestId] = msg.sender;

    // Emit an event to log the request for the NFT
    emit NftRequested(requestId, msg.sender);
}

}
