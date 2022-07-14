pragma solidity >=0.5.0<0.6.0;

import "@openzeppelin/contracts/token/ERC20/ERC20Capped.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";

/**
 * @title coin contract
 */
contract RunningPetCoin is ERC20Capped, ERC20Detailed, ERC20Burnable {

    // Address of coin vault
    // The vault will have all coin issued.
    address internal vault;

    // Address of  owner
    // The owner can change admin and vault address.
    address internal owner;

    // Address of coin admin
    // The admin can change reserve. The reserve is the amount of token
    // assigned to some address but not permitted to use.
    address internal admin;

    event OwnerChanged(address indexed previousOwner, address indexed newOwner);
    event VaultChanged(address indexed previousVault, address indexed newVault);
    event AdminChanged(address indexed previousAdmin, address indexed newAdmin);
    event ReserveChanged(address indexed _address, uint amount);

    /**
     * @dev reserved number of tokens per each address
     *
     * To limit token transaction for some period by the admin,
     * each address' balance cannot become lower than this amount
     *
     */
    mapping(address => uint) public reserves;

    /**
       * @dev modifier to limit access to the owner only
       */
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }

    /**
       * @dev limit access to the vault only
       */
    modifier onlyVault() {
        require(msg.sender == vault);
        _;
    }

    /**
       * @dev limit access to the admin only
       */
    modifier onlyAdmin() {
        require(msg.sender == admin);
        _;
    }

    /**
       * @dev limit access to owner or vault
       */
    modifier onlyOwnerOrVault() {
        require(msg.sender == owner || msg.sender == vault);
        _;
    }

    /**
     * @dev initialize ERC20
     *
     * all token will deposit into the vault
     * later, the vault, owner will be multi sign contract to protect privileged operations
     *
     * @param _symbol token symbol
     * @param _name   token name
     * @param _total          uint256
     * @param _decimals     uint8
     * @param _owner  owner address
     * @param _admin  admin address
     * @param _vault  vault address
     * @param _cap          uint256
     *
     */
    constructor (string memory _symbol, string memory _name, uint256 _total, uint8 _decimals, address _owner,
                 address _admin, address _vault, uint256 _cap)
        ERC20Detailed(_name, _symbol, _decimals) ERC20Capped(_cap * (10 ** uint(_decimals)))
    public {
        require(bytes(_symbol).length > 0);
        require(bytes(_name).length > 0);

        owner = _owner;
        admin = _admin;
        vault = _vault;

        // mint coins to the vault
        _mint(vault, _total * (10 ** uint(decimals())));
    }

    /**
     * @dev change the amount of reserved token
     *
     * @param _address the target address whose token will be frozen for future use
     * @param _reserve  the amount of reserved token
     *
     */
    function setReserve(address _address, uint _reserve) public onlyAdmin {
        require(_reserve <= totalSupply());
        require(_address != address(0));

        reserves[_address] = _reserve;
        emit ReserveChanged(_address, _reserve);
    }

    /**
     * @dev transfer token from sender to other
     * the result balance should be greater than or equal to the reserved token amount
     */
    function transfer(address _to, uint256 _value) public returns (bool) {
        // check the reserve
        require(balanceOf(msg.sender).sub(_value) >= reserveOf(msg.sender));
        return super.transfer(_to, _value);
    }

    /**
     * @dev change vault address
     *
     * @param _newVault new vault address
     */
    function setVault(address _newVault) public onlyOwner {
        require(_newVault != address(0));
        require(_newVault != vault);

        address _oldVault = vault;

        // change vault address
        vault = _newVault;
        emit VaultChanged(_oldVault, _newVault);
    }

    /**
     * @dev change owner address
     * @param _newOwner new owner address
     */
    function setOwner(address _newOwner) public onlyVault {
        require(_newOwner != address(0));
        require(_newOwner != owner);

        _addMinter(_newOwner);
        _removeMinter(owner);

        emit OwnerChanged(owner, _newOwner);
        owner = _newOwner;
    }

    /**
     * @dev change admin address
     * @param _newAdmin new admin address
     */
    function setAdmin(address _newAdmin) public onlyOwnerOrVault {
        require(_newAdmin != address(0));
        require(_newAdmin != admin);

        emit AdminChanged(admin, _newAdmin);
        admin = _newAdmin;
    }

    /**
     * @dev Transfer tokens from one address to another
     *
     * The _from's balance should be larger than the reserved amount(reserves[_from]) plus _value.
     *
     * NOTE: no one can tranfer from vault
     *
     */
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool) {
        require(_from != vault);
        require(_value <= balanceOf(_from).sub(reserves[_from]));
        return super.transferFrom(_from, _to, _value);
    }

    function getOwner() public view returns (address) {
        return owner;
    }

    function getVault() public view returns (address) {
        return vault;
    }

    function getAdmin() public view returns (address) {
        return admin;
    }

    function getOneCoin() public view returns (uint) {
        return (10 ** uint(decimals()));
    }

    /**
     * @dev get the amount of reserved token
     */
    function reserveOf(address _address) public view returns (uint _reserve) {
        return reserves[_address];
    }

    /**
     * @dev get the amount reserved token of the sender
     */
    function reserve() public view returns (uint _reserve) {
        return reserves[msg.sender];
    }
}
