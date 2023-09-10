// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/IERC1155MetadataURI.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ERC1155 is ERC165, IERC1155, IERC1155MetadataURI, Ownable {
    // Mapping from token ID to account balances
    mapping(uint256 => mapping(address => uint256)) private _balances;

    // Mapping from account to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    // Mapping from token ID to token URI
    mapping(uint256 => string) private _tokenURIs;

    // The base URI for all token URIs
    string private _baseTokenURI;

    bytes4 constant private INTERFACE_SIGNATURE_ERC165 = 0x01ffc9a7;
    bytes4 constant private INTERFACE_SIGNATURE_ERC1155 = 0xd9b67a26;

    constructor() {
        require(supportsInterface(INTERFACE_SIGNATURE_ERC165) || supportsInterface(INTERFACE_SIGNATURE_ERC1155),
            "This contract does not support the IERC1155 Standard Specification"
        );
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view override(ERC165, IERC165) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @dev Set the base URI for all token URIs.
     * @param baseTokenURI The new base URI.
     */
    function setBaseURI(string memory baseTokenURI) external onlyOwner {
        _baseTokenURI = baseTokenURI;
    }

    /**
     * @dev Get the base URI for all token URIs.
     * @return The base URI.
     */
    function baseURI() external view returns (string memory) {
        return _baseTokenURI;
    }

    /**
     * @dev Get the URI for a token ID.
     * @param tokenId The ID of the token.
     * @return The token URI.
     */
    function uri(uint256 tokenId) external view override returns (string memory) {
        return string(abi.encodePacked(_baseTokenURI, _tokenURIs[tokenId]));
    }

    /**
     * @dev See {IERC1155-balanceOf}.
     */
    function balanceOf(address account, uint256 tokenId) external view override returns (uint256) {
        return _balances[tokenId][account];
    }

    /**
     * @dev See {IERC1155-balanceOfBatch}.
     */
    function balanceOfBatch(address[] calldata accounts, uint256[] calldata tokenIds) external view override returns (uint256[] memory) {
        require(accounts.length == tokenIds.length, "ERC1155: accounts and tokenIds length mismatch");

        uint256[] memory batchBalances = new uint256[](accounts.length);

        for (uint256 i = 0; i < accounts.length; i++) {
            batchBalances[i] = _balances[tokenIds[i]][accounts[i]];
        }

        return batchBalances;
    }

    /**
     * @dev See {IERC1155-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) external override {
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    /**
     * @dev See {IERC1155-isApprovedForAll}.
     */
    function isApprovedForAll(address account, address operator) external view override returns (bool) {
        return _operatorApprovals[account][operator];
    }

    /**
     * @dev Set the URI for a token ID.
     * @param tokenId The ID of the token.
     * @param tokenURI The token URI.
     */
    function _setTokenURI(uint256 tokenId, string memory tokenURI) internal {
        _tokenURIs[tokenId] = tokenURI;
        emit URI(tokenURI, tokenId);
    }

    function _isContract(address _address) private view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(_address)
        }
        return size > 0;
    }

    /**
        @notice Transfers `_value` amount of an `_id` from the `_from` address to the `_to` address specified (with safety call).
        @dev Caller must be approved to manage the tokens being transferred out of the `_from` account (see "Approval" section of the standard).
        MUST revert if `_to` is the zero address.
        MUST revert if balance of holder for token `_id` is lower than the `_value` sent.
        MUST revert on any other error.
        MUST emit the `TransferSingle` event to reflect the balance change (see "Safe Transfer Rules" section of the standard).
        After the above conditions are met, this function MUST check if `_to` is a smart contract (e.g. code size > 0). If so, it MUST call `onERC1155Received` on `_to` and act appropriately (see "Safe Transfer Rules" section of the standard).
        @param _from    Source address
        @param _to      Target address
        @param _id      ID of the token type
        @param _value   Transfer amount
        @param _data    Additional data with no specified format, MUST be sent unaltered in call to `onERC1155Received` on `_to`
    */
    function safeTransferFrom(address _from, address _to, uint256 _id, uint256 _value, bytes calldata _data) external {

        require(_to != address(0x0), "_to must be non-zero.");
        require(_from == msg.sender || _operatorApprovals[_from][msg.sender] == true, "Unauthorized: 3rd party transfers require operator approval.");

        _balances[_id][_from] -= _value;
        _balances[_id][_to] += _value;

        emit TransferSingle(msg.sender, _from, _to, _id, _value);

        if (_isContract(_to)) {
            _doSafeTransferAcceptanceCheck(msg.sender, _from, _to, _id, _value, _data);
        }
    }

    /**
        @notice Transfers `_values` amount(s) of `_ids` from the `_from` address to the `_to` address specified (with safety call).
        @dev Caller must be approved to manage the tokens being transferred out of the `_from` account (see "Approval" section of the standard).
        MUST revert if `_to` is the zero address.
        MUST revert if length of `_ids` is not the same as length of `_values`.
        MUST revert if any of the balance(s) of the holder(s) for token(s) in `_ids` is lower than the respective amount(s) in `_values` sent to the recipient.
        MUST revert on any other error.
        MUST emit `TransferSingle` or `TransferBatch` event(s) such that all the balance changes are reflected (see "Safe Transfer Rules" section of the standard).
        Balance changes and events MUST follow the ordering of the arrays (_ids[0]/_values[0] before _ids[1]/_values[1], etc).
        After the above conditions for the transfer(s) in the batch are met, this function MUST check if `_to` is a smart contract (e.g. code size > 0). If so, it MUST call the relevant `ERC1155TokenReceiver` hook(s) on `_to` and act appropriately (see "Safe Transfer Rules" section of the standard).
        @param _from    Source address
        @param _to      Target address
        @param _ids     IDs of each token type (order and length must match _values array)
        @param _values  Transfer amounts per token type (order and length must match _ids array)
        @param _data    Additional data with no specified format, MUST be sent unaltered in call to the `ERC1155TokenReceiver` hook(s) on `_to`
    */
    function safeBatchTransferFrom(address _from, address _to, uint256[] calldata _ids, uint256[] calldata _values, bytes calldata _data) external {

        // MUST Throw on errors
        require(_to != address(0x0), "destination address must be non-zero.");
        require(_ids.length == _values.length, "_ids and _values array length must match.");
        require(_from == msg.sender || _operatorApprovals[_from][msg.sender] == true, "Need operator approval for 3rd party transfers.");

        for (uint256 i = 0; i < _ids.length; ++i) {
            uint256 id = _ids[i];
            uint256 value = _values[i];

            _balances[id][_from] -= value;
            _balances[id][_to] += value;
        }

        emit TransferBatch(msg.sender, _from, _to, _ids, _values);

        // Now that the balances are updated and the events are emitted,
        // call onERC1155BatchReceived if the destination is a contract.
        if (_isContract(_to)) {
            _doSafeBatchTransferAcceptanceCheck(msg.sender, _from, _to, _ids, _values, _data);
        }
    }

    /**
     * @dev Internal function to safely transfer tokens from one address to another.
     * @param from The address to transfer tokens from.
     * @param to The address to transfer tokens to.
     * @param tokenId The ID of the token type to transfer.
     * @param value The amount of tokens to transfer.
     * @param data Additional data to send along with the transfer.
     */
    function _safeTransfer(address from, address to, uint256 tokenId, uint256 value, bytes memory data) internal {
        require(to != address(0), "ERC1155: Transfers to the zero address are not allowed");
        require(_balances[tokenId][from] >= value, "ERC1155: Insufficient balance for transfer");

        _balances[tokenId][from] -= value;
        _balances[tokenId][to] += value;

        emit TransferSingle(msg.sender, from, to, tokenId, value);

        if (_isContract(to)) {
            _doSafeTransferAcceptanceCheck(msg.sender, from, to, tokenId, value, data);
        }
    }

    /**
     * @dev Internal function to perform safe batch transfer of tokens.
     * @param from The address to transfer tokens from.
     * @param to The address to transfer tokens to.
     * @param tokenIds The IDs of the token types to transfer.
     * @param values The amounts of tokens to transfer.
     * @param data Additional data to send along with the transfer.
     */
    function _safeBatchTransfer(address from, address to, uint256[] memory tokenIds, uint256[] memory values, bytes memory data) internal {
        require(tokenIds.length == values.length, "ERC1155: ids and values length mismatch");
        require(to != address(0), "ERC1155: transfer to the zero address");

        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            uint256 value = values[i];

            require(_balances[tokenId][from] >= value, "ERC1155: insufficient balance for transfer");

            _balances[tokenId][from] -= value;
            _balances[tokenId][to] += value;
        }

        emit TransferBatch(msg.sender, from, to, tokenIds, values);

        if (_isContract(to)) {
            _doSafeBatchTransferAcceptanceCheck(msg.sender, from, to, tokenIds, values, data);
        }
    }

    /**
     * @dev Internal function to check if the recipient is a smart contract and, if so, call its `onERC1155Received` function.
     * @param operator The address that initiated the transfer (i.e., msg.sender).
     * @param from The address that holds the tokens being transferred.
     * @param to The address that will receive the tokens.
     * @param tokenId The ID of the token being transferred.
     * @param value The amount of tokens being transferred.
     * @param data Additional data to send along with the transfer.
     */
    function _doSafeTransferAcceptanceCheck(address operator, address from, address to, uint256 tokenId, uint256 value, bytes memory data) private {
        //        bytes memory returnedData = Address.functionCall(
        //            abi.encodeWithSelector(
        //                IERC1155Receiver(to).onERC1155Received.selector,
        //                operator,
        //                from,
        //                tokenId,
        //                value,
        //                data
        //            ),
        //            "ERC1155: transfer to non ERC1155Receiver implementer"
        //        );

        //        require(
        //            abi.decode(returnedData, (bool)),
        //            "ERC1155: transfer to non ERC1155Receiver"
        //        );
    }

    /**
     * @dev Internal function to check if the recipient is a smart contract and, if so, call its `onERC1155BatchReceived` function.
     * @param operator The address that initiated the transfer (i.e., msg.sender).
     * @param from The address that holds the tokens being transferred.
     * @param to The address that will receive the tokens.
     * @param tokenIds The IDs of the tokens being transferred.
     * @param values The amounts of tokens being transferred.
     * @param data Additional data to send along with the transfer.
 */
    function _doSafeBatchTransferAcceptanceCheck(address operator, address from, address to, uint256[] memory tokenIds, uint256[] memory values, bytes memory data) private {
        //        bytes memory returnedData;
        //        for (uint256 i = 0; i < tokenIds.length; i++) {
        //            returnedData = Address.functionCall(
        //                abi.encodeWithSelector(
        //                    IERC1155Receiver(to).onERC1155BatchReceived.selector,
        //                    operator,
        //                    from,
        //                    tokenIds,
        //                    values,
        //                    data
        //                ),
        //                "ERC1155: batch transfer to non ERC1155Receiver implementer"
        //            );

        //            require(
        //                abi.decode(returnedData, (bool)),
        //                "ERC1155: batch transfer to non ERC1155Receiver"
        //            );
    }
}

