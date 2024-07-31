// SPDX-License-Identifier: UNLICENSED
// This smart contract code is proprietary.
// Unauthorized copying, modification, or distribution is strictly prohibited.
// For licensing inquiries or permissions, contact info@toolblox.net.
pragma solidity ^0.8.20;
import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts-upgradeable/v5.0.2/contracts/proxy/utils/Initializable.sol";
import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts-upgradeable/v5.0.2/contracts/access/OwnableUpgradeable.sol";
import "https://raw.githubusercontent.com/Ideevoog/Toolblox.Token/main/Contracts/NonTransferrableERC721Upgradeable.sol";
import "https://raw.githubusercontent.com/OpenZeppelin/openzeppelin-contracts-upgradeable/v5.0.2/contracts/token/ERC721/ERC721Upgradeable.sol";
import "https://raw.githubusercontent.com/Ideevoog/Toolblox.Token/main/Contracts/WorkflowBaseUpgradeable.sol";
/*
	Toolblox smart-contract workflow: https://app.toolblox.net/summary/profile_test_profile_v1
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
	function initialize(address _newOwner) public initializer {
		__Ownable_init(_newOwner);
		__NonTransferrableERC721_init();
		__ERC721_init("Profile - PROFILE test profile v1", "PROFILE");
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
	The following properties will be updated on blockchain:
	
	* `Name` (String)
*/
	function registerProfile(string calldata name) public returns (uint256) {
		uint256 id = _getNextId();
		Profile memory item;
		item.id = id;
		_assertOrAssignWallet(item);
		_setItemIdByName(item, 0);
		_setItemIdByWallet(item, 0);
		item.name = name;
		item.status = 0;
		items[id] = item;
		address newOwner = getItemOwner(item);
		_mint(newOwner, id);
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
	
	#### Checks and updates
	The following properties will be updated on blockchain:
	
	* `Name` (String)
*/
	function changeName(uint256 id,string calldata name) public returns (uint256) {
		Profile memory item = getItem(id);
		address oldOwner = getItemOwner(item);
		_assertStatus(item, 0);
		_setItemIdByName(item, 0);
		item.name = name;
		item.status = 0;
		items[id] = item;
		address newOwner = getItemOwner(item);
		if (newOwner != oldOwner) {
			_transfer(oldOwner, newOwner, id);
		}
		_setItemIdByName(item, id);
		emit ItemUpdated(id, item.status);
		return id;
	}
}