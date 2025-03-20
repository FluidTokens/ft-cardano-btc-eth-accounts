import { MaestroProvider,mConStr0, MeshTxBuilder, MeshWallet,resolveScriptHash,serializePlutusScript,pubKeyAddress,serializeAddressObj,BlockfrostProvider,deserializeAddress } from '@meshsdk/core';
const compiledCode="QUACODICE"
import cbor from "cbor";
import { applyParamsToScript } from "@meshsdk/core-csl"; 
import { Buffer } from "buffer";

export const handler = async (event) => {
    try {
        

        const {
           inputData
        } = JSON.parse(event.body);
        

        const maestroTestnet = new MaestroProvider({
            network: 'Preview',
            apiKey: 'HGKu5DjuRaOC5EOLOQ6Rl7Ngybqx8opu',
            turboSubmit: false,
        });
        const blockchainProvider = new BlockfrostProvider(
          'previewR5n6b2nOs73gJELTuQb4fZZskH1cdEjA'
        );
        const txBuilder = new MeshTxBuilder({
            fetcher: blockchainProvider,
            evaluator:blockchainProvider,
            verbose: true,
        });
        txBuilder.setNetwork("preview");

        // Initialize owner wallet using mnemonic key
        const ownerWallet = //QUA MI COLLEGO AL WALLET

        console.log(ownerWallet)
        const addressSigner = await ownerWallet.getChangeAddress();
        const { stakeCredentialHash, pubKeyHash } = deserializeAddress(addressSigner);
        // Placeholder wallet interaction (adjust as per your setup)
        const wallet = ownerWallet;  // Implement wallet connection code
        const utxos = await ownerWallet.getUtxos();
        const changeAddress = await wallet.getChangeAddress();
        const collateralUtxos = await wallet.getCollateral();
        const { txHash, outputIndex } = collateralUtxos[0].input;



      const script = cbor.encode(Buffer.from(compiledCode, "hex")).toString("hex");
     //let pubkey="02c341a570aded9e1cba4930aebff64af210d03473ea0fbfee8a3ab5bea15cd685"
 
      const scriptCbor = applyParamsToScript( 
        script, 
        [ [inputData.btcpubkey, pubKeyHash, inputData.ethpubkey],2], //in questo caso ho 3 utenti, BTC, cardano e ETH e almeno 2 devono approvare la tx 
        "Mesh", 
      ) 


 
      const plutusScript = { 
        code: scriptCbor, 
        version: "V3", 
      };




      let { address } = serializePlutusScript(plutusScript,hash,0,true); //ottengo l'address
      
      const SCaddress=address
      console.log("smart contract")
      console.log(SCaddress)

      //qua genero l'address ricevente dai dati pubkey e stakecred destinatario
      const receiver = pubKeyAddress(inputData.pubKeyHash,inputData.stakeCredentialHash)

      let destinatario=serializeAddressObj(receiver)
      console.log(destinatario)
        // Build the transaction

        // Initialize an empty object to store the aggregated amounts
        let aggregatedAssets = {};
        
        // Iterate through the starting UTXOs (assuming `inputData.utxos` contains the list of UTXOs)
        for (let utxo of inputData.utxos) {
            let startingUtxo = await maestroTestnet.get(`/transactions/${utxo.transactionHash}/outputs/${utxo.index.toString()}/txo`);
            
            startingUtxo.data.assets.forEach(item => {
                // Determine the asset unit for the current item
                let currentAssetUnit = item.unit 
                
                // If the assetUnit matches, aggregate the amounts
                if (!aggregatedAssets[currentAssetUnit]) {
                    aggregatedAssets[currentAssetUnit] = 0;
                }
        
                // Add the current asset amount to the aggregated total

                aggregatedAssets[currentAssetUnit] += parseInt(item.amount, 10);
                
                
            });
        }
        
        //qua molto interessante, le firme bitcoin vanno prima convertite da base64 in hex e poi si eliminano i primi due caratteri, mentre se ETH si fa slice
        const signature = inputData.btc ? Buffer.from(inputData.signature, "base64").toString("hex").substring(2) : inputData.signature.slice(0, -2);
        console.log("signature")
        console.log(signature)


        //cosa voglio mandare
        let assetUnit = inputData.policyId + inputData.assetNameHex;
        
        // Construct the asset unit string to match in the input data
        if(inputData.policyId==""){
            assetUnit='lovelace'
        }
        
        console.log(aggregatedAssets)
        
        // Now, create the assetsCopy by mapping through the aggregated assets
        let assetsCopy = Object.keys(aggregatedAssets).map(assetUnit => {
            const amount = aggregatedAssets[assetUnit];
        
            // If it's lovelace and its amount is greater than 4,000,000, reduce it by 1,000,000
            if (assetUnit === 'lovelace' && amount > 4000000) {
                const newLovelaceAmount = amount - 1000000;
                console.log("new lovelace amount:", newLovelaceAmount);
                return {
                    unit: assetUnit,
                    amount: newLovelaceAmount.toString()
                };
            }
        
            // Otherwise, return the asset without changes
            return {
                unit: assetUnit,
                amount: amount.toString()
            };
        });
        
        // Now, adjust the specific asset’s quantity based on inputData.qty
        const remainingAmounts = assetsCopy.map(item => {
            if (item.unit === assetUnit) {
                const newQuantity = parseInt(item.amount, 10) - inputData.qty;
                console.log("new quantity for asset:", newQuantity);
                return {
                    ...item,
                    amount: newQuantity.toString()
                };
            }
            return item; // Leave unchanged if it's not the asset being sent
        });

        // Log the updated amount array
        console.log(remainingAmounts);

    function cleanAndConvertAmounts(amountArray) {
    return amountArray.reduce((acc, item) => {
        const quantity = parseInt(item.amount, 10); // Convert to integer
        // Only include items where quantity is a valid number
        if (!isNaN(quantity)) {
            acc[item.unit] = quantity.toString(); // Convert quantity to a string
        }
        return acc;
    }, {});
}
function processAmounts(amountArray) {
    return amountArray
        .filter(item => !isNaN(parseInt(item.amount, 10)) && item.amount !== '0') // Filter out NaN amounts
        .map(item => ({
            unit: item.unit,
            quantity: String(item.amount) // Convert amount to string and rename to quantity
        }));
}
        let leftovers=cleanAndConvertAmounts(remainingAmounts)
        console.log(leftovers)

        console.log("utxos che sto inserendo")
        console.log(utxos)
        
    const payment_vkh = mConStr0([pubKeyHash]);
    const staking_vkh = mConStr0([stakeCredentialHash]); //secondo me qua è 0
    const staking_inline = mConStr0([mConStr0([staking_vkh])]);
    const addressCbor = mConStr0([payment_vkh, staking_inline]);
        

    //questa è la parte più CRUCIALE LORE, se la tx che costruirà ha senso su MESH verrà inviata SE e solo SE il redeemer sarà giusto
// il redeemer è definito così per l'invio

/*pub type Redeemermultisig {
  SendMulti {
    signatures: List<Multisignature>,
    utxos: List<OutputReference>,
    policy: ByteArray,
    assetname: ByteArray,
    amount: Int,
    policyInput: ByteArray,
    assetnameInput: ByteArray,
    amountInput: Int,
    spendingscriptflag: Int,
    pubkey: ByteArray,
    stakingscriptflag: Int,
    stakekey: ByteArray,
    datumflag: Int,
    datum: Data,
    payment_index: Int,
    fee: Int,
    signer: Address,
  }
  MergeMulti
  StakeMulti { signatures: List<Multisignature>, deadline: Int }


  Le signatures ora sono definite così
//pub type Multisignature {
  signature: ByteArray,
  position: Int,
}


}*/


        let redeemer=mConStr0([[
            mConstr0([signatureBTC,posizioneBTC]), //devo dirgli in che posizione si trova questa persona nella lista dei parametri che gli ho passato, btc nel nostro caso era posizione 0
            mConstr0([signatureETH,posizioneETH])],//mi ricordo la conversione delle firme prima di usarle qua, eth posizione 2
        [...inputData.utxos.map(utxo => mConStr0([utxo.transactionHash, utxo.index]))],//qua lista delle utxos che uso
        inputData.policyId,//policy dell'asset che mando
        inputData.assetNameHex,//assetname dell'asset che mando
        inputData.qty,//quantity considerando i decimali
        inputData.policyIdInput,//Se ricevo token qua la policy
        inputData.assetNameHexInput,//se ricevo token qua lassetname
        inputData.qtyInput,//Se ricevo token qua la quantità
        inputData.spendingscriptflag,//qua se il ricevente è uno smart contract con spending key  flag 1/0
        inputData.pubKeyHash,//qua hash ricevente
        inputData.stakingscriptflag,//qua se ricevente has staking smart contract  flag 1/0
        inputData.stakeCredentialHash,//qua hash del ricevente staking
        inputData.datumflag,//qua se c'è datum, flag 1/0
        inputData.datum,//qua il datum
        0, //qua l'output dove metterà il pagamento, solitamnente primo output
        1000000,//qua la fee che mi prendo io che mando la tx, quindi multisig accetterà di ricevere indietro ammontare iniziale - inviato - 1 ADA
        addressCbor //qua l'address di chi sta firmando
        ]);
        
        
        

    txBuilder
    .selectUtxosFrom(utxos)
    .txInCollateral(txHash, outputIndex) // Replace with actual collateral TX ID
    

// Iterate over `utxos` and add `txIn` for each one
inputData.utxos.forEach(utxo => {
    txBuilder.spendingPlutusScriptV3()
        .txIn(utxo.transactionHash, utxo.index)
        .txInInlineDatumPresent()
        .txInRedeemerValue(redeemer)
        .txInScript(scriptCbor);
});

txBuilder
    .txOut(destinatario, [{ unit: assetUnit, quantity: inputData.qty.toString() }])
    .txOut(SCaddress, processAmounts(remainingAmounts)) // TODO
    .changeAddress(changeAddress) //qua manca la firma LORENZO aggiungi required signer di chi manda
    
    let unsignedTx = await txBuilder.complete();

        // Sign and submit the transaction
        const signedTx = await wallet.signTx(unsignedTx);
        const txHashFinal = await wallet.submitTx(signedTx);
        

return {
    statusCode: 200,
    headers: {
        "Access-Control-Allow-Origin": "*", // Allow all origins
        "Access-Control-Allow-Headers": "Content-Type",
        "Access-Control-Allow-Methods": "OPTIONS,POST,GET"
    },
    body: "txHashFinal",
};
} catch (error) {
    console.error('Error:', error);
    return {
        statusCode: 500,
        headers: {
            "Access-Control-Allow-Origin": "*", // Allow all origins
            "Access-Control-Allow-Headers": "Content-Type",
            "Access-Control-Allow-Methods": "OPTIONS,POST,GET"
        },
        body: JSON.stringify({ error: 'Transaction failed', details: error.message }),
    };
}
};
