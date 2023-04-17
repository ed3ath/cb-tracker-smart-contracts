const { expect } = require("chai")
const { ethers } = require("hardhat")

let sManager, game
let owner, alice, bob, carl, mary, jane, treasury

describe("Test contracts", function () {
    it("Initialize contracts", async () => {
        [owner, alice, bob, carl, mary, jane, treasury] = await ethers.getSigners()
        
        const CBTrackerToken = await ethers.getContractFactory("CBTrackerToken")
        const SeedManager = await ethers.getContractFactory("SeedManager")
        const ColorGame = await ethers.getContractFactory("ColorGame")

        token = await CBTrackerToken.deploy()
        game = await ColorGame.deploy()
        sManager = await SeedManager.deploy()

        await token.mint(alice.address, ethers.utils.parseEther('1000'))
        await token.mint(bob.address, ethers.utils.parseEther('1000'))
        await token.mint(carl.address, ethers.utils.parseEther('1000'))

        await sManager.initialize()

        await sManager.grantRole(await sManager.GAME_MASTER(), game.address)
        await game.initialize(treasury.address, token.address, sManager.address, 600)
        
        expect((await game.getCurrentRound()).toString()).equals('1')
    })

    it("Alice and Bob placed a bet on round 1", async () => {
        await game.connect(alice).bet(await game.COLOR_RED(), ethers.utils.parseEther('10'))
        const [aliceColor, aliceAmount] = await game.getUserRoundBet(alice.address)

        await game.connect(bob).bet(await game.COLOR_BLUE(), ethers.utils.parseEther('5'))
        const [bobColor, bobAmount] = await game.getUserRoundBet(bob.address)

        expect(aliceColor.toString()).equals((await game.COLOR_RED()).toString())
        expect(aliceAmount.toString()).equals(ethers.utils.parseEther('10'))

        expect(bobColor.toString()).equals((await game.COLOR_BLUE()).toString())
        expect(bobAmount.toString()).equals(ethers.utils.parseEther('5'))
    })
    
    it("Game master select round color", async () => {
        await game.pickRandomColor()
        console.log(await game.roundColors(await game.getCurrentRound()))
    })
})
