const OrchestratedReceiverMock = artifacts.require('OrchestratedReceiverMock')
const OrchestratedCallerMock = artifacts.require('OrchestratedCallerMock')

// @ts-ignore
import { expectRevert } from '@openzeppelin/test-helpers';
import { Contract } from "../shared/fixtures"
import { formatBytes32String as toBytes32 } from 'ethers/lib/utils'

contract('Orchestrated', async (accounts: string[]) =>  {
  let [ deployer, user, malicious ] = accounts;

  let receiver: Contract;
  let caller: Contract;

  const DEFAULT_ADMIN_ROLE = "";
  const YIELD_CONTRACT = "YIELD_CONTRACT";

  beforeEach(async() => {
    receiver = await OrchestratedReceiverMock.new({ from: deployer });
    caller = await OrchestratedCallerMock.new(receiver.address, { from: deployer });
  })

  // Setting up orchestration
  it('initializes DEFAULT_ADMIN_ROLE as the admin for YIELD_CONTRACT', async () => {
      assert.equal(await receiver.getRoleAdmin(toBytes32(YIELD_CONTRACT)), toBytes32(DEFAULT_ADMIN_ROLE))
  })

  it('gives DEFAULT_ADMIN_ROLE to the deployer', async () => {
    assert.equal(await receiver.hasRole(toBytes32(DEFAULT_ADMIN_ROLE), deployer), true)
  })

  it('only deployer can orchestrate contracts', async () => {
    await expectRevert(
      receiver.orchestrate(caller.address, { from: malicious }),
      "AccessControl: sender must be an admin to grant",
    )
    await receiver.orchestrate(caller.address, { from: deployer })
    assert.equal(await receiver.hasRole(toBytes32(YIELD_CONTRACT), caller.address), true)
  })

  it('only contracts can be orchestrated', async () => {
    await expectRevert(
      receiver.orchestrate(malicious, { from: malicious }),
      "Orchestrated: Only contracts can be orchestrated",
    )
  })

  // Using orchestrated contracts
  describe("with orchestrated contracts", () => {
    beforeEach(async() => {
      await receiver.orchestrate(caller.address, { from: deployer })
    })

    it('only deployer can call onlyDeployer functions', async () => {
      await expectRevert(
        receiver.testOnlyDeployer({ from: malicious }),
        "Orchestrated: Only deployer",
      )
      await receiver.testOnlyDeployer({ from: deployer });
    })

    it('only orchestrated contracts can call onlyOrchestrated functions', async () => {
      await expectRevert(
        receiver.testOnlyOrchestrated({ from: malicious }),
        "Orchestrated: Only orchestrated",
      )
      await caller.testOnlyOrchestrated({ from: user });
    })
  })
})
