// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";


contract NFTMarket is ReentrancyGuard{
    using Counters for Counters.Counter;
    Counters.Counter private _itemIds;      //the id of the item
    Counters.Counter private _itemsSold;    //id of the items that are sold

    event MarketItemCreated(uint indexed itemId, address indexed nftContract, uint indexed tokenId, address seller, address owner, uint price, bool sold);

    address payable owner;
    uint listingPrice = 0.025 ether;    //this is for the owner of the contract to earn commision when someone lists their nft on the network

    constructor() {
        owner = payable(msg.sender);
    }

    struct MarketItem{
        uint itemId;
        address nftContract;
        uint tokenId;
        address payable seller;
        address payable owner;
        uint price;
        bool sold;
    }

    struct RoyaltyInfo{
        address receiver;
        uint royaltyFraction;
    }

    mapping(address => mapping(uint => RoyaltyInfo)) private tokenRoyaltyInfo;
    mapping(uint => MarketItem) private idToMarketItem; //points from uint to struct MarketItem where uint will be same as 'itemId' in the struct
    uint[] internal itemids;

    //returns us the listing price
    function getListingPrice() public view returns(uint){
        return listingPrice;
    }

    /*
        this function takes in the contract address of the nft, the tokenId of the nft, and the price of the nft.
        after checking some basic requiremen. we do the following things:
        1. first we get the current value of itemIds that are stored separately
        2. then we take the idToMarketItem mapping and us k 'itemId' k index pr hum ne struct ki values store krwa di where itemId is the id of the nft, nftContract 
        is the contract address of the nft, tokenId is the id of the nft, seller of the nft is msg.sender and the owner is address 0 since no one owns the nft atm.
        then the price and the status of the nft that is it sold ot not.
        3. then we transfer the nft from msg.sender to the address of the contract also the id of the token.
    */
    function createMarketItem(address nftContract, uint tokenId, uint price, uint royaltyFee) public payable nonReentrant {
        require(price > 0, "Price must be at least 1 wei");
        require(msg.value == listingPrice, "Price must be equal or greter than listing price");

        _itemIds.increment();
        uint itemId = _itemIds.current(); 

        idToMarketItem[itemId] = MarketItem(itemId, nftContract, tokenId, payable(msg.sender), payable(address(0)), price, false);
        itemids.push(itemId);
        IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);
        //royalty fee
        tokenRoyaltyInfo[nftContract][itemId] = RoyaltyInfo(msg.sender, royaltyFee);
        emit MarketItemCreated(itemId, nftContract, tokenId, msg.sender, address(this), price, false);

    }

    /*
        in this function we sell the nft. this function takes in the contract address of the nft and the item id. 
        also, we store the price and the token id of the nft in a seperate variable. then we put a simple check.
        now what we have to do is, k pehle hamain paise bhejne hain, then nft ki ownership change krni hai, then fee contract owner ko bhejne hai, then status change krna hai
    */

    function createMarketSale(address nftContract, uint itemId) public payable nonReentrant {
        uint price = idToMarketItem[itemId].price;
        uint tokenId = idToMarketItem[itemId].tokenId;
        require(msg.value == price, "Please submit the asking price in order to complete the purchase");
        // crypto transfer to nft owner
        idToMarketItem[itemId].seller.transfer(msg.value);
        //transfer
        IERC721(nftContract).transferFrom(address(this), msg.sender, tokenId);
        idToMarketItem[itemId].owner = payable(msg.sender);
        idToMarketItem[itemId].sold = true;
        _itemsSold.increment();

        RoyaltyInfo memory royaltyObject = tokenRoyaltyInfo[nftContract][itemId];
        //roylaty

        //platform fee
        payable(royaltyObject.receiver).transfer((royaltyObject.royaltyFraction)/100);
        //addres(this)> listing
        //msg.sender(rolaty holder)
        uint tempListingPrice = listingPrice - royaltyObject.royaltyFraction;
        //call
        payable(owner).transfer(tempListingPrice);
    }

    /*
        this function returns us all of the unsold items. this function takes in no argument but returns an array of MarketItem structure. 
        after storing the current value of item id, we get the unsold items that exist by subtracting the items sold from the total item count.

        then we create a an array which will store the MarketItem struct. for that we run a loop and check id the address is 0 or not. if it 0, it means 
        that the item is not sold. if there is not a 0 address, item is sold. 

        them we take the id of the address(0) and store that in the array at the index of the Id. then we increment the index.
    */

    function fetchMarketItems() public view returns(MarketItem[] memory){
        //uint itemCount = _itemIds.current();
        uint unsoldItemCount = itemids.length - _itemsSold.current();
        uint currentIndex = 0;

        MarketItem[] memory items = new MarketItem[](unsoldItemCount);
        for(uint i=0; i<itemids.length; i++){
            if(idToMarketItem[i].owner == address(0)){
                //uint currentId = idToMarketItem[i+1].itemId;
                MarketItem storage currentItem = idToMarketItem[i];
                items[currentIndex] = currentItem;
                currentIndex +=1;
            }
        }
        return items;
    }


    /*
        in this function, we fetch the nfts that I own. this function takes in no parameters but returns a structure array of MarketItem. after storing in the 
        variables we get the count that how many nfts are there that the msg.sender own. we get that number and store that in itemCount.

        then i run a loop that checks if i am the owner of the nft or not. if I am the owner, we store it in the array and then finally return the array.
    */

    function fetchMyNfts() public view returns (MarketItem[] memory) {
        //uint totalItemCount = _itemIds.current();
        //uint itemCount = 0;
        uint currentIndex = 0;
        MarketItem[] memory items = new MarketItem[](itemids.length);
        for(uint i = 0; i< itemids.length; i++){
            if(idToMarketItem[i].owner == msg.sender){
                MarketItem storage currentItem = idToMarketItem[i];
                items[currentIndex] = currentItem;
                currentIndex+=1;
            }
        }
        
        return items;
    }

    /*
        this function returns all of the items that i have created. this function takes in no parameters but returns an array of MarketItem.
        we run a loop that checks the number of items that i own by msg.sender. and store that number. then i run another loop that gets us all the NFTs that I own.
    */

    function fetchItemsCreated() public view returns (MarketItem[] memory){
        // uint totalItemCount = _itemIds.current();
        // uint itemCount = 0;
        uint currentIndex = 0;

        MarketItem[] memory items = new MarketItem[](itemids.length);
        for(uint i = 0; i< itemids.length; i++){
            if(idToMarketItem[i].seller == msg.sender){
                MarketItem storage currentItem = idToMarketItem[i];
                items[currentIndex] = currentItem;
                currentIndex+=1;
            }
        }

        return items;
    }

    function getDetails(uint itemId) external view returns(MarketItem memory){
        return idToMarketItem[itemId];
    }

}


