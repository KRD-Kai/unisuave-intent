
# Intent-based swaps on Suave


Suave, in development by Flashbots, is a shared sequencing layer that enables a range of MEV applications, including decentralized block building and orderflow auction mechanisms. Intent-based defi services like CoW protocol have already proven themselves to be valuable services, but they currently rely on heavily centralized infrastructure.  This project aims to serve as a  PoC for a decentralized intent-solver auction mechanism on Suave chain. 

I started this project at the ETHGlobal istanbul hackathon ([project page](https://ethglobal.com/showcase/uni-suave-intents-5t2t3)).

## Description
End users (swappers) create order intents, specifying data like what tokens they wish to trade, how much they expect to receive and the max. amount they are willing to give. They call a newOrder function, passing intent data. The intent, including data like the signature (which should not be shared initially), is saved confidentially, in storage by creating a new bid. An event is also emitted which reveals certain public information/hints, including order info and the bidId, which is used to retreive confidential intent data later on. 

Solvers listen to these events, do their solving an then call a settle function. The contract evaluates the solvers' solutions for the current auction (on a l1 block-by-block basis), and ranks them accordingly. At the end of the auction the top solution is posted to a settlement contract on l1. 

## How it's made
I ran a local Suave node and deployed a contract on Suave that handles the auction. I added a custom precompile (a feature of the MEVM) to suave-geth that lets me retrieve the goerli block number within the suave contract. This lets the contract run block-by-block auction for an order. The contract currently only supports solutions for one order for this PoC, but should allow for batch auctions and coincidence of wants in the future. 

When solvers receive new order information, they generate a solution and submit this to the contract. In this implementation, they pass in bundle data - which encompasses a settlement transaction.  When the solver submits their data, the contract checks if they are still within the current auction block. If not it will settle the previous auction by executing the current top-ranking solver bundle, and then update the current block. Solver gets their solution ranked against by simulating the bundle using the simulateBundle precompile which returns an EGP score. If their score is greater than the one for this block, replace it. The solver solutions are also stored confidentially. Only the ranking and bidIds are public.

The scoring approach described above is naive, and a higher EGP may not be representative of the users' best interest, but rather that of the solvers. Among other future additions and changes, the contract should evaluate/verify the surplus created by solvers, potentially by running simulations and comparing against the amounts expressed in the user intents. 



