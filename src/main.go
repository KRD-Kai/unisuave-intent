package main

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"strings"

	"github.com/KRD-Kai/unisuave-intent/framework"
	"github.com/ethereum/go-ethereum/accounts/abi"
)

type BlockNumberUpdated struct {
	BlockNumber uint64
}

func main() {
	fr := framework.New()
	contract := fr.DeployContract("out/UniSuave.sol/UniSuave.json")

	fmt.Println("Contract deployed at:", contract.Address())
	receipt := contract.SendTransaction("updateExternalBlockNumber", nil, nil)
	fmt.Println("Logs:", receipt.Logs)

	fileContent, err := ioutil.ReadFile("out/UniSuave.sol/UniSuave.json")
	if err != nil {
		log.Fatalf("Failed to read contract ABI file: %v", err)
	}

	var contractJSON struct {
		ABI json.RawMessage `json:"abi"`
	}

	err = json.Unmarshal(fileContent, &contractJSON)
	if err != nil {
		log.Fatalf("Failed to unmarshal JSON file: %v", err)
	}

	contractAbi, err := abi.JSON(strings.NewReader(string(contractJSON.ABI)))
	if err != nil {
		log.Fatalf("Failed to parse contract ABI: %v", err)
	}

	for _, vLog := range receipt.Logs {
		if len(vLog.Topics) > 0 && vLog.Topics[0].Hex() == contractAbi.Events["blockNumberUpdated"].ID.Hex() {
			event := BlockNumberUpdated{}
			err := contractAbi.UnpackIntoInterface(&event, "blockNumberUpdated", vLog.Data)
			if err != nil {
				log.Fatalf("Failed to unpack log: %v", err)
			}
			fmt.Printf("Decoded Block Number: %d\n", event.BlockNumber)
		}
	}
}
