// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";


/// @custom:security-contact contact@altify.io
contract Spongebobbiez is ERC721, ERC721Enumerable, Pausable, Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;
    using Strings for uint256;

    Counters.Counter private _tokenIdCounter;

    string private baseURI;

    uint immutable maxSupply = 5;
    uint publicMintPrice = 0.001 ether;
    uint privateMintPrice = 0.0001 ether;
    uint whitelistMintCap = 3;

    address payable public paymentReceiver;

    mapping(address => bool) public whitelisted;
    mapping(address => uint) mintedTokens;

    enum Stage {
        closed,
        whitelist,
        publicOpen
    }

    Stage public mintStage;

    modifier mintOpen(Stage _currentStage){
        require(_currentStage == Stage.whitelist || _currentStage == Stage.publicOpen, "Minting is currently closed");
        _;
    }

    constructor() ERC721("Spongebobbiez", "SPGBZ") {
        mintStage = Stage.closed;
        paymentReceiver = payable(msg.sender);
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }
    
    receive() external payable {
        paymentReceiver.transfer(msg.value);
    }

    
    function mint() public payable mintOpen(mintStage) whenNotPaused returns(bool) {
        require(totalSupply() < maxSupply, "Max supply limit reached");
        uint currentTokenID = _tokenIdCounter.current() + 1;

        if(mintStage == Stage.whitelist){
            require(whitelisted[msg.sender], "User is not whitelisted");
            require(msg.value >= privateMintPrice, "Insufficient Funds");
            require(mintedTokens[msg.sender] < whitelistMintCap, "Whitelist Mint Cap Exceeded");
            mintedTokens[msg.sender] += 1;
            _tokenIdCounter.increment();
            (bool whitelistSuccess, ) = payable(msg.sender).call{value: privateMintPrice}('');
            _safeMint(msg.sender, currentTokenID);
            return whitelistSuccess;
        } else if (mintStage == Stage.publicOpen){
            require(msg.value >= publicMintPrice, "Insufficient Funds");
            mintedTokens[msg.sender] += 1;
            _tokenIdCounter.increment();
            (bool publicSuccess, ) = payable(msg.sender).call{value: publicMintPrice}('');
            _safeMint(msg.sender, currentTokenID);
            return publicSuccess;
        } else {
            return false;
        }
        
    }

    function whitelist(address _user) external onlyOwner {
        require(whitelisted[_user] == false, "User is already whitelisted!");
        whitelisted[_user] = true;
    }


    function withdraw() external onlyOwner nonReentrant returns(bool) {
        uint contractBalance = address(this).balance;
        require(contractBalance > 0, "Contract funds already withdrawn");
        (bool withdrawSuccess, ) = payable(msg.sender).call{value: contractBalance}('');
        return withdrawSuccess;
    }


    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize)
        internal
        whenNotPaused
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }


    function setBaseURI(string memory _newURI) public onlyOwner {
        baseURI = _newURI;
    }


    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        _requireMinted(tokenId);

        string memory currentURI = _baseURI();
        return bytes(currentURI).length > 0 ? string(abi.encodePacked(baseURI, tokenId.toString(), ".json")) : "";
    } 


    function updateMintStage() external onlyOwner {
        require(mintStage == Stage.closed || mintStage == Stage.whitelist);

        Stage currentMintStage = mintStage;

        if(mintStage == Stage.closed){
            mintStage = Stage.whitelist;
        } else if (mintStage == Stage.whitelist){
            mintStage = Stage.publicOpen;
        }

        assert(currentMintStage != mintStage);
    }

    // The following functions are overrides required by Solidity.

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}