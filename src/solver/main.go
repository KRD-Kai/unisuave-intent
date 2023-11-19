package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"io/ioutil"
	"log"
	"math/big"
	"strings"

	"github.com/ethereum/go-ethereum"
	"github.com/ethereum/go-ethereum/accounts/abi"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/core/types"
	"github.com/ethereum/go-ethereum/ethclient"
)

// Define a struct for the OrderCreated event
type OrderCreatedEvent struct {
	BidId         [16]byte // Suave.BidId is bytes16
	Creator       common.Address
	SellToken     common.Address
	BuyToken      common.Address
	ValidTo       uint32
	MinSellAmount *big.Int
	BuyAmount     *big.Int
}

func main() {
	contractAddressFlag := flag.String("address", "", "The contract address")
	flag.Parse()

	// Validate the inputs
	if *contractAddressFlag == "" {
		log.Fatal("Missig argument --address")
	}

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

	client, err := ethclient.Dial("ws://127.0.0.1:8546")
	if err != nil {
		log.Fatalf("Failed to connect to the Ethereum client: %v", err)
	}

	contractAddress := common.HexToAddress(*contractAddressFlag)
	query := ethereum.FilterQuery{
		Addresses: []common.Address{contractAddress},
	}

	logs := make(chan types.Log)
	sub, err := client.SubscribeFilterLogs(context.Background(), query, logs)
	if err != nil {
		log.Fatal(err)
	}

	for {
		select {
		case err := <-sub.Err():
			log.Fatal(err)
		case vLog := <-logs:
			fmt.Println("Log:", vLog) // Raw log

			event := OrderCreatedEvent{}
			err := contractAbi.UnpackIntoInterface(&event, "OrderCreated", vLog.Data)
			if err != nil {
				log.Fatal(err)
			}

			fmt.Printf("Decoded Event: %+v\n", event)
		}
	}
}
