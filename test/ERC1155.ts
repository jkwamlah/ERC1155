import {ethers} from 'hardhat';
import {expect} from 'chai';
import {loadFixture} from "@nomicfoundation/hardhat-toolbox/network-helpers";

async function deployDonationsMgtFixture() {
    const [deployer, user1, user2] = await ethers.getSigners();
    const ERC1155 = await ethers.getContractFactory("ERC1155");
    const erc1155 = await ERC1155.deploy();

    return {
        erc1155,
        deployer,
        user1,
        user2
    };
}

describe('ERC1155Contract', async () => {
    describe('Events', () => {

        it('should emit TransferSingle event when tokens are transferred', async () => {
            const {erc1155, deployer, user1} = await loadFixture(deployDonationsMgtFixture);

            const tokenId = 1;
            const amount = 100;
            // await erc1155.mint(deployer.address, tokenId, amount);
            const transaction = await erc1155.safeTransferFrom(deployer.address, user1.address, tokenId, amount, '0x');
            await expect(transaction).to.emit(erc1155, 'TransferSingle').withArgs(deployer.address, deployer.address, user1.address, tokenId, amount);
        });

        it('should emit TransferBatch event when tokens are transferred in batch', async () => {
            const {erc1155, deployer, user1} = await loadFixture(deployDonationsMgtFixture);

            const tokenIds = [1, 2];
            const amounts = [100, 200];
            // await erc1155.batchMint(deployer.address, tokenIds, amounts);
            const tx = await erc1155.safeBatchTransferFrom(deployer.address, user1.address, tokenIds, amounts, '0x');
            await expect(tx).to.emit(erc1155, 'TransferBatch').withArgs(deployer.address, deployer.address, user1.address, tokenIds, amounts);
        });

        it('should emit ApprovalForAll event when operator approval is set', async () => {
            const {erc1155, deployer, user1} = await loadFixture(deployDonationsMgtFixture);

            const operator = user1.address;
            const tx = await erc1155.setApprovalForAll(operator, true);
            await expect(tx).to.emit(erc1155, 'ApprovalForAll').withArgs(deployer.address, operator, true);
        });
    });

    describe('Functions', () => {
        it('should transfer tokens safely using safeTransferFrom', async () => {
            const {erc1155, deployer, user1} = await loadFixture(deployDonationsMgtFixture);

            const tokenId = 1;
            const amount = 100;
            // await erc1155.mint(deployer.address, tokenId, amount);
            await erc1155.safeTransferFrom(deployer.address, user1.address, tokenId, amount, '0x');
            const balanceDeployer = await erc1155.balanceOf(deployer.address, tokenId);
            const balanceUser1 = await erc1155.balanceOf(user1.address, tokenId);
            expect(balanceDeployer).to.equal(0);
            expect(balanceUser1).to.equal(amount);
        });

        it('should transfer tokens safely in batch using safeBatchTransferFrom', async () => {
            const {erc1155, deployer, user1} = await loadFixture(deployDonationsMgtFixture);

            const tokenIds = [1, 2];
            const amounts = [100, 200];
            // await erc1155.batchMint(deployer.address, tokenIds, amounts);
            await erc1155.safeBatchTransferFrom(deployer.address, user1.address, tokenIds, amounts, '0x');
            for (let i = 0; i < tokenIds.length; i++) {
                const balanceDeployer = await erc1155.balanceOf(deployer.address, tokenIds[i]);
                const balanceUser1 = await erc1155.balanceOf(user1.address, tokenIds[i]);
                expect(balanceDeployer).to.equal(0);
                expect(balanceUser1).to.equal(amounts[i]);
            }
        });

        it('should get the balance of an account\'s tokens using balanceOf', async () => {
            const {erc1155, deployer} = await loadFixture(deployDonationsMgtFixture);

            const tokenId = 1;
            const amount = 100;
            // await erc1155.mint(deployer.address, tokenId, amount);
            const balance = await erc1155.balanceOf(deployer.address, tokenId);
            expect(balance).to.equal(amount);
        });

        it('should get the balance of multiple account/token pairs using balanceOfBatch', async () => {
            const {erc1155, deployer, user1} = await loadFixture(deployDonationsMgtFixture);

            const tokenIds = [1, 2];
            const amounts = [100, 200];
            // await erc1155.batchMint(deployer.address, tokenIds, amounts);
            const balances = await erc1155.balanceOfBatch([deployer.address, user1.address], tokenIds);
            expect(balances[0]).to.deep.equal(amounts);
            expect(balances[1]).to.deep.equal([0, 0]);
        });

        it('should set operator approval for all tokens using setApprovalForAll', async () => {
            const {erc1155, deployer, user1} = await loadFixture(deployDonationsMgtFixture);

            const operator = user1.address;
            await erc1155.setApprovalForAll(operator, true);
            const isApproved = await erc1155.isApprovedForAll(deployer.address, operator);
            expect(isApproved).to.equal(true);
        });

        it('should check operator approval using isApprovedForAll', async () => {
            const {erc1155, deployer, user1} = await loadFixture(deployDonationsMgtFixture);

            const operator = user1.address;
            await erc1155.setApprovalForAll(operator, true);
            const isApproved = await erc1155.isApprovedForAll(deployer.address, operator);
            expect(isApproved).to.equal(true);
        });
    });
});
