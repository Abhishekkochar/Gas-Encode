// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.4;

// Custom errors to decerease the deployment cost
// error Gas_Contract_Only_Admin_Check_Caller_not_admin();
error Only_Owner();
error Sender_Is_Not_WhiteListed();
// error Address_Is_Not_WhiteListed();
// error Tier_Over_4();
error Zero_Address_Not_Valid();
error Not_Sufficent_Balance();
error Name_More_Than_8Bits();
error ID_Not_Greater_Than_Zero();
error Amount_Not_Greater_Than_Zero();
// error Must_Not_Greater_Than_255();
// error Contact_Hacked_Contract_Support();
error Amount_Not_To_Be_Bigger_Than_3();

contract GasContract {
    bool wasLastOdd = true;
    uint8 internal constant tradePercent = 12;
    address public immutable contractOwner;
    uint256 internal paymentCounter = 0;
    uint256 public immutable totalSupply; // cannot be updated
    mapping(address => uint256) public balances;
    mapping(address => Payment[]) public payments;
    mapping(address => uint8) public whitelist;
    mapping(address => bool) public isOddWhitelistUser;
    // mapping(address => bool) public administrators;
    //Can't we optimize this way by mapping administrators?
    address[5] public administrators;

    enum PaymentType {
        Unknown,
        BasicPayment,
        Refund,
        Dividend,
        GroupPayment
    }
    // PaymentType constant defaultPayment = PaymentType.Unknown;

    History[] public paymentHistory; // when a payment was updated

    struct Payment {
        PaymentType paymentType;
        bool adminUpdated;
        address recipient;
        address admin; // administrators address
        uint256 paymentID;
        uint256 amount;
        bytes recipientName; // max 8 characters
    }

    struct History {
        uint256 lastUpdate;
        address updatedBy;
        uint256 blockNumber;
    }

    struct ImportantStruct {
        uint64 valueA; // max 3 digits
        uint64 valueB; // max 3 digits
        uint256 bigValue;
    }

    mapping(address => ImportantStruct) public whiteListStruct;

    event AddedToWhitelist(address userAddress, uint8 tier);

    modifier onlyAdminOrOwner() {
        if (checkForAdmin(msg.sender) || msg.sender == contractOwner) {
            _;
        } else {
            revert Only_Owner();
        }
    }

    modifier checkIfWhiteListed(address sender) {
        if (msg.sender != sender) revert Sender_Is_Not_WhiteListed();
        _;
    }

    event supplyChanged(address indexed, uint256 indexed);
    event Transfer(address recipient, uint256 amount);
    event PaymentUpdated(
        address admin,
        uint256 ID,
        uint256 amount,
        bytes recipient
    );
    event WhiteListTransfer(address indexed);

    constructor(address[] memory _admins, uint256 _totalSupply) {
        contractOwner = msg.sender;
        totalSupply = _totalSupply;
        uint256 intialBalance = 0;
        for (uint256 ii = 0; ii < 5; ii++) {
            if (_admins[ii] != address(0)) {
                administrators[ii] = _admins[ii];

                if (_admins[ii] == msg.sender) {
                    intialBalance = intialBalance + _totalSupply;
                    // balances[msg.sender] = _totalSupply;
                    emit supplyChanged(_admins[ii], _totalSupply);
                } else {
                    delete balances[_admins[ii]];
                    emit supplyChanged(_admins[ii], 0);
                }
            }
        }
        balances[msg.sender] = intialBalance;
    }

    function getPaymentHistory()
        external
        view
        returns (History[] memory paymentHistory_)
    {
        return paymentHistory;
    }

    function checkForAdmin(address _user) public view returns (bool admin_) {
        bool admin = false;
        for (uint256 ii = 0; ii < administrators.length; ii++) {
            if (administrators[ii] == _user) {
                admin = true;
            }
        }
        return admin;
    }

    function balanceOf(address _user) public view returns (uint256 balance) {
        return balances[_user];
    }

    //Can it be removed or replaced with a public bol variable with true value.
    function getTradingMode() public pure returns (bool mode) {
        return true;
    }

    function addHistory(address _updateAddress) internal {
        History memory history;
        history.blockNumber = block.number;
        history.lastUpdate = block.timestamp;
        history.updatedBy = _updateAddress;
        paymentHistory.push(history);
    }

    function getPayments(address _user)
        external
        view
        returns (Payment[] memory payments_)
    {
        if (_user == address(0)) revert Zero_Address_Not_Valid();
        return payments[_user];
    }

    function transfer(
        address _recipient,
        uint256 _amount,
        string calldata _name
    ) external returns (bool) {
        uint256 currentBal = balances[msg.sender];
        if (currentBal <= _amount) revert Not_Sufficent_Balance();
        if (bytes(_name).length > 9) revert Name_More_Than_8Bits();
        //Gas optimistaion
        currentBal -= _amount;
        balances[_recipient] += _amount;
        emit Transfer(_recipient, _amount);
        Payment memory payment;
        // payment.admin = address(0);
        // payment.adminUpdated = false;
        payment.paymentType = PaymentType.BasicPayment;
        payment.recipient = _recipient;
        payment.amount = _amount;
        payment.recipientName = bytes(_name);
        payment.paymentID = ++paymentCounter;
        payments[msg.sender].push(payment);
        return true;
    }

    function updatePayment(
        address _user,
        uint256 _ID,
        uint256 _amount,
        PaymentType _type
    ) public onlyAdminOrOwner {
        if (_ID <= 0) revert ID_Not_Greater_Than_Zero();
        if (_amount <= 0) revert Amount_Not_Greater_Than_Zero();
        if (_user == address(0)) revert Zero_Address_Not_Valid();
        //@to-do check if msg.sender affect the gas .

        //payments memory _payment;
        for (uint256 ii = 0; ii < payments[_user].length; ii++) {
            if (payments[_user][ii].paymentID == _ID) {
                payments[_user][ii].adminUpdated = true;
                payments[_user][ii].admin = _user;
                payments[_user][ii].paymentType = _type;
                payments[_user][ii].amount = _amount;
                addHistory(_user);
                emit PaymentUpdated(
                    msg.sender,
                    _ID,
                    _amount,
                    bytes(payments[_user][ii].recipientName)
                );
            }
        }
    }

    function addToWhitelist(address _userAddrs, uint8 _tier)
        public
        onlyAdminOrOwner
    {
        whitelist[_userAddrs] = _tier > 3 ? 3 : _tier;
        isOddWhitelistUser[_userAddrs] = wasLastOdd;
        wasLastOdd = wasLastOdd ? false : true;
        emit AddedToWhitelist(_userAddrs, _tier);
    }

    function whiteTransfer(
        address _recipient,
        uint256 _amount,
        ImportantStruct memory _struct
    ) public checkIfWhiteListed(msg.sender) {
        //@to-do validate if msg.sneder can be used for gas optimization
        if (balances[msg.sender] < _amount) revert Not_Sufficent_Balance();

        //@t0-validate this below condition is incorrect , please verify.
        if (_amount <= 3) revert Amount_Not_To_Be_Bigger_Than_3();

        balances[msg.sender] -= _amount;
        balances[_recipient] += _amount;
        balances[msg.sender] += whitelist[msg.sender];
        balances[_recipient] -= whitelist[msg.sender];

        // whiteListStruct[msg.sender] = ImportantStruct(0, 0, 0);
        ImportantStruct storage newImportantStruct = whiteListStruct[
            msg.sender
        ];
        newImportantStruct.valueA = _struct.valueA;
        newImportantStruct.bigValue = _struct.bigValue;
        newImportantStruct.valueB = _struct.valueB;
        emit WhiteListTransfer(_recipient);
    }
}
