// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
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

    constructor(string memory baseTokenURI) {
        _baseTokenURI = baseTokenURI;
        _registerInterface(type(IERC1155).interfaceId);
        _registerInterface(type(IERC1155MetadataURI).interfaceId);
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
    function baseURI() external view override returns (string memory) {
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

    /**
     * @dev Internal function to safely transfer tokens from one address to another.
     * @param from The address to transfer tokens from.
     * @param to The address to transfer tokens to.
     * @param tokenId The ID of the token type to transfer.
     * @param value The amount of tokens to transfer.
     * @param data Additional data to send along with the transfer.
     */
    function _safeTransfer(address from, address to, uint256 tokenId, uint256 value, bytes memory data) internal {
        require(to != address(0), "ERC1155: transfer to the zero address");
        require(_balances[tokenId][from] >= value, "ERC1155: insufficient balance for transfer");

        _balances[tokenId][from] -= value;
        _balances[tokenId][to] += value;

        emit TransferSingle(msg.sender, from, to, tokenId, value);

        if (to.isContract()) {
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

        if (to.isContract()) {
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
        bytes memory returndata = to.functionCall(
            abi.encodeWithSelector(
                IERC1155Receiver(to).onERC1155Received.selector,
                operator,
                from,
                tokenId,
                value,
                data
            ),
            "ERC1155: transfer to non ERC1155Receiver implementer"
        );

        require(
            abi.decode(returndata, (bool)),
            "ERC1155: transfer to non ERC1155Receiver"
        );
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
        bytes memory returnData = to.functionCall(
            abi.encodeWithSelector(
                IERC1155Receiver(to).onERC1155BatchReceived.selector,
                operator,
                from,
                tokenIds,
                values,
                data
            ),
            "ERC1155: batch transfer to non ERC1155Receiver implementer"
        );

        require(
            abi.decode(returnData, (bool)),
            "ERC1155: batch transfer to non ERC1155Receiver"
        );
    }
}

