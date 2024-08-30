// SPDX-License-Identifier: UNLICENSED
// This smart contract code is proprietary.
// Unauthorized copying, modification, or distribution is strictly prohibited.
// For licensing inquiries or permissions, contact info@toolblox.net.
pragma solidity ^0.8.20;
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@tool_blox/contracts/contracts/NonTransferrableERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@tool_blox/contracts/contracts/WorkflowBaseUpgradeable.sol";
import "@tool_blox/contracts/contracts/utils/Validate.sol";
/*
	Toolblox smart-contract workflow: https://app.toolblox.net/summary/rddtor_profile_contract_v1
	# Description
	
	This contract serves as the holder for decentralized social network profile. The profile is an soulbound upgradeable NFT (ERC721).
	 * It is upgradeable (OpenZeppelin Initializable) to be able to add new properties, states and state transitions in subsequent iterations of development - properties such as Rating, Friends, Bio and more.
	 * It is an NFT (ERC721) to be able to verify and check data in NFT portals and wallets.
	 * It is soulbound to the owner wallet address (non-transferrable).
	
	## Remarks
	
	The *Name* property of the profile will contain a hashed version of the username. Hashing will take place off-chain.
*/
contract ProfileWorkflow  is Initializable, OwnableUpgradeable, NonTransferrableERC721Upgradeable, WorkflowBaseUpgradeable{
	struct Profile {
		uint id;
		uint64 status;
		address wallet;
		string image;
		string name;
		string description;
	}
	mapping(uint => Profile) public items;
	function _assertOrAssignWallet(Profile memory item) private view {
		address wallet = item.wallet;
		if (wallet != address(0))
		{
			require(_msgSender() == wallet, "Invalid Wallet");
			return;
		}
		item.wallet = _msgSender();
	}
	function initialize(address _newOwner, string memory tokenName, string memory tokenSymbol) public initializer onlyInitializing {
		__Ownable_init(_newOwner);
		__NonTransferrableERC721_init();
		__ERC721_init(tokenName, tokenSymbol);
		__WorkflowBase_init();
	}
    struct AddressSlot {
        address value;
    }
    function getAddressSlot(bytes32 slot) internal pure returns (AddressSlot storage r) {
        assembly {
            r.slot := slot
        }
    }
	function getProxyAdminAddress() public view returns (address) {
        return getAddressSlot(0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103).value;
    }
	function setOwner(address _newOwner) public {
		transferOwnership(_newOwner);
	}
/*
	Available statuses:
	0 Active (owner Wallet)
*/
	function _assertStatus(Profile memory item, uint64 status) private pure {
		require(item.status == status, "Cannot run Workflow action; unexpected status");
	}
	function getItem(uint256 id) public view returns (Profile memory) {
		Profile memory item = items[id];
		require(item.id == id, "Cannot find item with given id");
		return item;
	}
	function getLatest(uint256 cnt) public view returns(Profile[] memory) {
		uint256[] memory latestIds = getLatestIds(cnt);
		Profile[] memory latestItems = new Profile[](latestIds.length);
		for (uint256 i = 0; i < latestIds.length; i++) latestItems[i] = items[latestIds[i]];
		return latestItems;
	}
	function getPage(uint256 cursor, uint256 howMany) public view returns(Profile[] memory) {
		uint256[] memory ids = getPageIds(cursor, howMany);
		Profile[] memory result = new Profile[](ids.length);
		for (uint256 i = 0; i < ids.length; i++) result[i] = items[ids[i]];
		return result;
	}
	function getItemOwner(Profile memory item) private view returns (address itemOwner) {
				if (item.status == 0) {
			itemOwner = item.wallet;
		}
        else {
			itemOwner = address(this);
        }
        if (itemOwner == address(0))
        {
            itemOwner = address(this);
        }
	}
	
	mapping(address => uint) public itemsByWallet;
	function getItemIdByWallet(address wallet) public view returns (uint) {
		return itemsByWallet[wallet];
	}
	function getItemByWallet(address wallet) public view returns (Profile memory) {
		return getItem(getItemIdByWallet(wallet));
	}
	function _setItemIdByWallet(Profile memory item, uint id) private {
		if (item.wallet == address(0))
		{
			return;
		}
		uint existingItemByWallet = itemsByWallet[item.wallet];
		require(
			existingItemByWallet == 0 || existingItemByWallet == item.id,
			"Cannot set Wallet. Another item already exist with same value."
		);
		itemsByWallet[item.wallet] = id;
	}
	
	mapping(string => uint) public itemsByName;
	function getItemIdByName(string calldata name) public view returns (uint) {
		return itemsByName[name];
	}
	function getItemByName(string calldata name) public view returns (Profile memory) {
		return getItem(getItemIdByName(name));
	}
	function _setItemIdByName(Profile memory item, uint id) private {
		if (bytes(item.name).length == 0)
		{
			return;
		}
		uint existingItemByName = itemsByName[item.name];
		require(
			existingItemByName == 0 || existingItemByName == item.id,
			"Cannot set Name. Another item already exist with same value."
		);
		itemsByName[item.name] = id;
	}
	function getId(uint id) public view returns (uint){
		return getItem(id).id;
	}
	function getStatus(uint id) public view returns (uint64){
		return getItem(id).status;
	}
	function getWallet(uint id) public view returns (address){
		return getItem(id).wallet;
	}
	function getImage(uint id) public view returns (string memory){
		return getItem(id).image;
	}
	function getName(uint id) public view returns (string memory){
		return getItem(id).name;
	}
	function getDescription(uint id) public view returns (string memory){
		return getItem(id).description;
	}
/*
	### Transition: 'Register profile'
	This transition creates a new object and puts it into `Active` state.
	
	#### Transition Parameters
	For this transition, the following parameters are required: 
	
	* `Name` (Text)
	
	#### Access Restrictions
	Access is specifically restricted to the user with the address from the `Wallet` property. If `Wallet` property is not yet set then the method caller becomes the objects `Wallet`.
	
	#### Checks and updates
	The following checks are done before any changes take place:
	
	* The condition ``Validate.NotEmpty( Name ) && Validate.OnlyAlphaNumAndSpace( Name )`` needs to be true or the following error will be returned: *"Invalid name"*.
	
	The following properties will be updated on blockchain:
	
	* `Name` (String)
*/
	function registerProfile(string calldata name) public returns (uint256) {
		uint256 id = _getNextId();
		Profile memory item;
		item.id = id;
		_assertOrAssignWallet(item);
		require(Validate.notEmpty( name ) && Validate.onlyAlphaNumAndSpace( name ), "Invalid name");
		_setItemIdByName(item, 0);
		_setItemIdByWallet(item, 0);
		item.name = name;
		item.status = 0;
		items[id] = item;
		address newOwner = getItemOwner(item);
		_safeMint(newOwner, id);
		_setItemIdByName(item, id);
		_setItemIdByWallet(item, id);
		emit ItemUpdated(id, item.status);
		return id;
	}
/*
	### Transition: 'Change name'
	This transition begins from `Active` and leads to the state `Active`.
	
	#### Transition Parameters
	For this transition, the following parameters are required: 
	
	* `Id` (Integer) - Profile identifier
	* `Name` (Text)
	
	#### Access Restrictions
	Access is specifically restricted to the user with the address from the `Wallet` property. If `Wallet` property is not yet set then the method caller becomes the objects `Wallet`.
	
	#### Checks and updates
	The following checks are done before any changes take place:
	
	* The condition ``Validate.NotEmpty( Name ) && Validate.OnlyAlphaNumAndSpace( Name )`` needs to be true or the following error will be returned: *"Invalid name"*.
	
	The following properties will be updated on blockchain:
	
	* `Name` (String)
*/
	function changeName(uint256 id,string calldata name) public returns (uint256) {
		Profile memory item = getItem(id);
		address oldOwner = getItemOwner(item);
		_assertOrAssignWallet(item);
		_assertStatus(item, 0);
		require(Validate.notEmpty( name ) && Validate.onlyAlphaNumAndSpace( name ), "Invalid name");
		_setItemIdByName(item, 0);
		_setItemIdByWallet(item, 0);
		item.name = name;
		item.status = 0;
		items[id] = item;
		address newOwner = getItemOwner(item);
		if (newOwner != oldOwner) {
			_transfer(oldOwner, newOwner, id);
		}
		_setItemIdByName(item, id);
		_setItemIdByWallet(item, id);
		emit ItemUpdated(id, item.status);
		return id;
	}
}