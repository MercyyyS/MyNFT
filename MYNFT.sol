 // SPDX-License-Identifier: MIT

pragma solidity >=0.8.7 <0.9.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract MYNFT is ERC721Enumerable, Ownable {
    using Strings for uint256;

    string public baseURI;
    string public baseExtension = ".json";
    string public hiddenMetadataUri;

    uint256 public cost;
    uint256 public maxSupply;
    uint256 public maxMintAmountPerTx;
    // Number of nfts is limited to 3 per user during whitelisting
    uint256 public nftPerAddressLimit;

    bool public paused = true;
    bool public revealed = false;
    bool public whitelistMintEnabled = false;

    address[] public whitelistedAddresses;
    mapping(address => uint256) public addressMintedBalance;

    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _cost,
        uint256 _maxSupply,
        uint256 _nftPerAddressLimit,
        uint256 _maxMintAmountPerTx,
        string memory _hiddenMetadataUri
    ) ERC721(_name, _symbol) {
        setHiddenMetadataUri(_hiddenMetadataUri);
        changeCost(_cost);
        changeMaxMintAmountPerTx(_maxMintAmountPerTx);
        maxSupply = _maxSupply;
        nftPerAddressLimit = _nftPerAddressLimit;
    }

    // public
    function mint(uint256 _mintAmount) public payable {
        require(!paused, "the contract is paused");
        require(_mintAmount != 0, "need to mint at least 1 NFT");
        require(
            _mintAmount <= maxMintAmountPerTx,
            "max mint amount per session exceeded"
        );
        uint256 supply = totalSupply();
        require(supply + _mintAmount <= maxSupply, "max NFT limit exceeded");

        if (msg.sender != owner()) {
            if (whitelistMintEnabled == true) {
                require(isWhitelisted(msg.sender), "user is not whitelisted");
                uint256 ownerMintedCount = addressMintedBalance[msg.sender];
                require(
                    ownerMintedCount + _mintAmount <= nftPerAddressLimit,
                    "max NFT per address exceeded"
                );
            }
            require(msg.value >= cost * _mintAmount, "insufficient funds");
        }

        for (uint256 i = 1; i <= _mintAmount; ) {
            addressMintedBalance[msg.sender]++;
            _safeMint(msg.sender, supply + i);
            unchecked {
                ++i;
            }
        }
    }

    // Returns the correct amount the user needs to pay for the mint
    function getmintPayValue(uint256 _mintAmount) 
    public 
    view 
    returns(uint)
    {
        return cost * _mintAmount;
    }


    function walletOfOwner(address _owner)
        public
        view
        returns (uint256[] memory)
    {
        uint256 ownerTokenCount = balanceOf(_owner);
        uint256[] memory tokenIds = new uint256[](ownerTokenCount);
        for (uint256 i; i < ownerTokenCount; ) {
            tokenIds[i] = tokenOfOwnerByIndex(_owner, i);
            unchecked {
                ++i;
            }
        }
        return tokenIds;
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override
        returns (string memory)
    {
        require(
            _exists(tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );

        if (revealed == false) {
            return hiddenMetadataUri;
        }

        string memory currentBaseURI = _baseURI();
        return
            bytes(currentBaseURI).length > 0
                ? string(
                    abi.encodePacked(
                        currentBaseURI,
                        tokenId.toString(),
                        baseExtension
                    )
                )
                : "";
    }

    //only owner

    function startWhitelisting() external onlyOwner {
        require(paused && !whitelistMintEnabled, "whitelisting impossible");
        pause(false);
        setWhitelistMintEnabled(true);
    }

    // Deletes the previous set of users and set this set
    function whitelistUsers(address[] calldata _users)
        public
        onlyOwner
    {
        delete whitelistedAddresses;
        whitelistedAddresses = _users;
    }

    function whitelistUser(address _user)
    public 
    onlyOwner{
        whitelistedAddresses.push(_user);
    }

    function isWhitelisted(address _user) public view returns (bool) {
        uint256 whitelistedCount = whitelistedAddresses.length;
        for (uint256 i; i < whitelistedCount; ) {
            if (whitelistedAddresses[i] == _user) {
                return true;
            }
            unchecked {
                ++i;
            }
        }
        return false;
    }

    function startPresale(uint256 _newCost, uint256 _newmaxMintAmount)
        external
        onlyOwner
    {
        require(!paused && whitelistMintEnabled, "Presale impossible");
        setWhitelistMintEnabled(false);
        changeCost(_newCost);
        changeMaxMintAmountPerTx(_newmaxMintAmount);
    }

    function startPublicSale(
        string memory _newBaseURI,
        uint256 _newCost,
        uint256 _newmaxMintAmount
    ) external  onlyOwner {
        require(
            !paused && !whitelistMintEnabled && !revealed,
            "Public sale impossible"
        );
        reveal(_newBaseURI);
        changeCost(_newCost);
        changeMaxMintAmountPerTx(_newmaxMintAmount);
    }

    function reveal(string memory _newBaseURI) public  onlyOwner {
        revealed = true;
        setBaseURI(_newBaseURI);
    }

    function changeNftPerAddressLimit(uint256 _limit) public  onlyOwner {
        nftPerAddressLimit = _limit;
    }

    function changeCost(uint256 _newCost) public onlyOwner {
        cost = _newCost;
    }

    function changeMaxMintAmountPerTx(uint256 _newmaxMintAmount)
        public
        onlyOwner
    {
        maxMintAmountPerTx = _newmaxMintAmount;
    }

    function setBaseURI(string memory _newBaseURI) public  onlyOwner {
        baseURI = _newBaseURI;
    }

    function setBaseExtension(string memory _newBaseExtension)
        public
        onlyOwner
    {
        baseExtension = _newBaseExtension;
    }

    function setHiddenMetadataUri(string memory _hiddenMetadataUri)
        public
        onlyOwner
    {
        hiddenMetadataUri = _hiddenMetadataUri;
    }

    function pause(bool _state) public  onlyOwner {
        paused = _state;
    }

    function setWhitelistMintEnabled(bool _state) public  onlyOwner {
        whitelistMintEnabled = _state;
    }


    function withdraw() public  onlyOwner {
        (bool os, ) = payable(owner()).call{value: address(this).balance}("");
        require(os);
    }

    // internal
    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }
}