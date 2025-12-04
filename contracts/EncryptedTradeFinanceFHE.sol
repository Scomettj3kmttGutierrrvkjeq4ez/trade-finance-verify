// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { FHE, euint32, ebool } from "@fhevm/solidity/lib/FHE.sol";
import { SepoliaConfig } from "@fhevm/solidity/config/ZamaConfig.sol";

contract EncryptedTradeFinanceFHE is SepoliaConfig {
    struct EncryptedTradeDocument {
        uint256 id;
        euint32 encryptedBillOfLading;
        euint32 encryptedInvoice;
        euint32 encryptedPartyInfo;
        uint256 timestamp;
    }

    struct DecryptedTradeDocument {
        string billOfLading;
        string invoice;
        string partyInfo;
        bool isVerified;
    }

    uint256 public documentCount;
    mapping(uint256 => EncryptedTradeDocument) public encryptedDocuments;
    mapping(uint256 => DecryptedTradeDocument) public decryptedDocuments;

    mapping(string => euint32) private encryptedVerificationCount;
    string[] private verificationCategories;

    mapping(uint256 => uint256) private requestToDocumentId;

    event DocumentSubmitted(uint256 indexed id, uint256 timestamp);
    event DecryptionRequested(uint256 indexed id);
    event DocumentVerified(uint256 indexed id);

    modifier onlySubmitter(uint256 documentId) {
        // Add access control logic in real implementation
        _;
    }

    /// @notice Submit encrypted trade documents
    function submitEncryptedDocument(
        euint32 encryptedBillOfLading,
        euint32 encryptedInvoice,
        euint32 encryptedPartyInfo
    ) public {
        documentCount += 1;
        uint256 newId = documentCount;

        encryptedDocuments[newId] = EncryptedTradeDocument({
            id: newId,
            encryptedBillOfLading: encryptedBillOfLading,
            encryptedInvoice: encryptedInvoice,
            encryptedPartyInfo: encryptedPartyInfo,
            timestamp: block.timestamp
        });

        decryptedDocuments[newId] = DecryptedTradeDocument({
            billOfLading: "",
            invoice: "",
            partyInfo: "",
            isVerified: false
        });

        emit DocumentSubmitted(newId, block.timestamp);
    }

    /// @notice Request decryption of a trade document
    function requestDocumentDecryption(uint256 documentId) public onlySubmitter(documentId) {
        EncryptedTradeDocument storage doc = encryptedDocuments[documentId];
        require(!decryptedDocuments[documentId].isVerified, "Already verified");

        bytes32 ;
        ciphertexts[0] = FHE.toBytes32(doc.encryptedBillOfLading);
        ciphertexts[1] = FHE.toBytes32(doc.encryptedInvoice);
        ciphertexts[2] = FHE.toBytes32(doc.encryptedPartyInfo);

        uint256 reqId = FHE.requestDecryption(ciphertexts, this.decryptDocument.selector);
        requestToDocumentId[reqId] = documentId;

        emit DecryptionRequested(documentId);
    }

    /// @notice Callback for decrypted trade document
    function decryptDocument(
        uint256 requestId,
        bytes memory cleartexts,
        bytes memory proof
    ) public {
        uint256 documentId = requestToDocumentId[requestId];
        require(documentId != 0, "Invalid request");

        EncryptedTradeDocument storage eDoc = encryptedDocuments[documentId];
        DecryptedTradeDocument storage dDoc = decryptedDocuments[documentId];
        require(!dDoc.isVerified, "Already verified");

        FHE.checkSignatures(requestId, cleartexts, proof);

        string[] memory results = abi.decode(cleartexts, (string[]));

        dDoc.billOfLading = results[0];
        dDoc.invoice = results[1];
        dDoc.partyInfo = results[2];
        dDoc.isVerified = true;

        if (!FHE.isInitialized(encryptedVerificationCount["verified"])) {
            encryptedVerificationCount["verified"] = FHE.asEuint32(0);
            verificationCategories.push("verified");
        }
        encryptedVerificationCount["verified"] = FHE.add(
            encryptedVerificationCount["verified"],
            FHE.asEuint32(1)
        );

        emit DocumentVerified(documentId);
    }

    /// @notice Get decrypted trade document
    function getDecryptedDocument(uint256 documentId) public view returns (
        string memory billOfLading,
        string memory invoice,
        string memory partyInfo,
        bool isVerified
    ) {
        DecryptedTradeDocument storage d = decryptedDocuments[documentId];
        return (d.billOfLading, d.invoice, d.partyInfo, d.isVerified);
    }

    /// @notice Get encrypted verification count
    function getEncryptedVerificationCount(string memory category) public view returns (euint32) {
        return encryptedVerificationCount[category];
    }
}
