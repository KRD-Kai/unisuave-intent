package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"math/big"
	"time"

	"github.com/KRD-Kai/unisuave-intent/framework"
	"github.com/ethereum/go-ethereum/common"
)

func main() {
	fr := framework.New()

	fundBalance := big.NewInt(100000000000000000)
	userAddr := framework.GeneratePrivKey()

	fr.FundAccount(userAddr.Address(), fundBalance)

	contractAddressFlag := flag.String("address", "", "The contract address")
	flag.Parse()

	if *contractAddressFlag == "" {
		log.Fatal("You must supply a contract address using --address flag")
	}

	// Create a contract instance
	contractAddress := common.HexToAddress(*contractAddressFlag)
	contract := fr.RetrieveContract(contractAddress, "out/UniSuave.sol/UniSuave.json")

	type Order struct {
		Creator       common.Address
		SellToken     common.Address
		BuyToken      common.Address
		ValidTo       uint32
		MinSellAmount *big.Int
		BuyAmount     *big.Int
	}

	orderIntent := struct {
		Order     Order
		Nonce     *big.Int
		Signature []byte
	}{
		Order: Order{
			Creator:       userAddr.Address(),
			SellToken:     common.HexToAddress("3a92d216b7C754c1AA669FbC35a95e1Aa7E5c0BD"),
			BuyToken:      common.HexToAddress("21b501Dfb1BA027350B6094CE0f16863aBF2fe37"),
			ValidTo:       uint32(time.Now().Add(24 * time.Hour).Unix()),
			MinSellAmount: big.NewInt(1000),
			BuyAmount:     big.NewInt(500),
		},
		// Placeholders
		Nonce:     big.NewInt(0),
		Signature: make([]byte, 32),
	}

	orderIntentData, err := json.Marshal(orderIntent)
	if err != nil {
		log.Fatalf("Failed to marshal order intent: %v", err)
	}

	// Send the transaction on suave
	contractAddr := contract.Ref(userAddr)
	receipt := contractAddr.SendTransaction("newOrder", nil, orderIntentData)

	fmt.Println("New order tx receipt: ", receipt)

}
