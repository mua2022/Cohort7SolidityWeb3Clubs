// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/Ownable.sol";

contract BookStore is Ownable {
    struct Book {
        string title;
        string author;
        uint256 price; // Price in wei
        uint256 stock;
        bool isAvailable;
    }

    mapping(uint256 => Book) public books;
    mapping(address => uint256) public loyaltyPoints;
    mapping(address => bool) public subscribers;

    address[] public subscriberList;
    uint256[] public bookIds;

    event BookAdded(uint256 indexed bookId, string title, string author, uint256 price, uint256 stock);
    event PurchaseInitiated(uint256 indexed bookId, address indexed buyer, address indexed seller, uint256 quantity);
    event PurchaseConfirmed(uint256 indexed bookId, address indexed buyer, address indexed seller, uint256 quantity);
    event SubscriptionAdded(address indexed subscriber);
    event SubscriptionRemoved(address indexed subscriber);

    constructor(address initialOwner) Ownable(initialOwner) {
        transferOwnership(initialOwner);
    }

    function addBook(
        uint256 _bookId,
        string memory _title,
        string memory _author,
        uint256 _price,
        uint256 _stock
    ) public onlyOwner {
        require(books[_bookId].price == 0, "Book already exists with this ID.");
        books[_bookId] = Book({
            title: _title,
            author: _author,
            price: _price * 1 ether, // Convert to wei
            stock: _stock,
            isAvailable: _stock > 0
        });
        bookIds.push(_bookId);
        emit BookAdded(_bookId, _title, _author, _price, _stock);
    }

    function getBooks(uint256 _bookId)
        public
        view
        returns (
            string memory,
            string memory,
            uint256,
            uint256,
            bool
        )
    {
        Book memory book = books[_bookId];
        return (book.title, book.author, book.price, book.stock, book.isAvailable);
    }

    function buyBook(uint256 _bookId, uint256 _quantity) public payable {
        Book storage book = books[_bookId];
        require(book.isAvailable, "This book is not available.");
        require(book.stock >= _quantity, "Not enough stock available.");

        uint256 totalPrice = book.price * _quantity;
        require(msg.value == totalPrice, "Incorrect payment amount.");

        emit PurchaseInitiated(_bookId, msg.sender, owner(), _quantity);

        // Transfer payment to the owner
        payable(owner()).transfer(msg.value);

        // Add loyalty points for the buyer
        loyaltyPoints[msg.sender] += _quantity * 10; // 10 points per book
    }

    function confirmPurchase(uint256 _bookId, uint256 _quantity) public onlyOwner {
        Book storage book = books[_bookId];
        require(book.stock >= _quantity, "Not enough stock to confirm purchase.");

        book.stock -= _quantity;
        if (book.stock == 0) {
            book.isAvailable = false;
        }

        emit PurchaseConfirmed(_bookId, msg.sender, owner(), _quantity);
    }

    function addSubscription(address _subscriber) public onlyOwner {
        require(!subscribers[_subscriber], "Subscriber already exists.");
        subscribers[_subscriber] = true;
        subscriberList.push(_subscriber);
        emit SubscriptionAdded(_subscriber);
    }

    function removeSubscription(address _subscriber) public onlyOwner {
        require(subscribers[_subscriber], "Subscriber does not exist.");
        subscribers[_subscriber] = false;
        emit SubscriptionRemoved(_subscriber);
    }

    // Loyalty Program
    function addPoints(address _user, uint256 _points) public onlyOwner {
        loyaltyPoints[_user] += _points;
    }

    function getUserPoints(address _user) public view returns (uint256) {
        return loyaltyPoints[_user];
    }

    // Discount Contract
    function getDiscountedPrice(uint256 _bookId, uint256 _points)
        public
        view
        returns (uint256)
    {
        Book memory book = books[_bookId];
        uint256 discount = (_points >= 100) ? book.price / 10 : 0; // 10% discount for 100+ points
        return book.price - discount;
    }

    function setDiscount(
        uint256 _bookId,
        uint256 _percentageDiscount
    ) public onlyOwner {
        require(_percentageDiscount <= 100, "Discount cannot exceed 100%");
        Book storage book = books[_bookId];
        uint256 discountAmount = (book.price * _percentageDiscount) / 100;
        book.price -= discountAmount;
    }
}
