usePlugin("@nomiclabs/buidler-truffle5");
usePlugin("solidity-coverage");
usePlugin("buidler-gas-reporter");

module.exports = {
    solc: {
        version: "0.6.10",
        optimizer: {
            enabled: true,
            runs: 1000
        },
    },
    gasReporter: {
        enabled: true
    },
    networks: {
        buidlerevm: {
            accounts: [
                {
                    privateKey: "0xFFFE05032D46E7A2DB4FB9836C4D89120F1471BA838A456436673444DC84F440",
                    balance: "0xFFFFFFFFFFFFFFFFFFFFFFFF"
                },
                {
                    privateKey: "0xFFFE05032D46E7A2DB4FB9836C4D89120F1471BA838A456436673444DC84F441",
                    balance: "0xFFFFFFFFFFFFFFFFFFFFFFFF"
                },
                {
                    privateKey: "0xFFFE05032D46E7A2DB4FB9836C4D89120F1471BA838A456436673444DC84F442",
                    balance: "0xFFFFFFFFFFFFFFFFFFFFFFFF"
                },
                {
                    privateKey: "0xFFFE05032D46E7A2DB4FB9836C4D89120F1471BA838A456436673444DC84F443",
                    balance: "0xFFFFFFFFFFFFFFFFFFFFFFFF"
                },
                {
                    privateKey: "0xFFFE05032D46E7A2DB4FB9836C4D89120F1471BA838A456436673444DC84F444",
                    balance: "0xFFFFFFFFFFFFFFFFFFFFFFFF"
                },
            ],
        },
    },
};