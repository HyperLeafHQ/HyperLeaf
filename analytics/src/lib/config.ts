export type Chain = { id:number; name:string; rpc:string };
export type Asset = {id:string;symbol:string;name:string;kind:'erc20'|'native';chain:keyof typeof CHAINS;address?:string;price:'dexscreener'|'coingecko'|'none'};

export const CHAINS={
  hyperEVM:{id:999,name:'HyperEVM',rpc:'https://rpc.hyperliquid.xyz/evm'},
  robinhood:{id:4663,name:'Robinhood Chain',rpc:process.env.ROBINHOOD_RPC||'https://rpc.mainnet.chain.robinhood.com'},
  bsc:{id:56,name:'BNB Smart Chain',rpc:process.env.BSC_RPC||'https://bsc-dataseed.binance.org'},
  base:{id:8453,name:'Base',rpc:process.env.BASE_RPC||'https://mainnet.base.org'},
  ethereum:{id:1,name:'Ethereum',rpc:process.env.ETH_RPC||'https://cloudflare-eth.com'},
  berachain:{id:80094,name:'Berachain',rpc:process.env.BERACHAIN_RPC||'https://rpc.berachain.com'}
} as const;

export const ASSETS:Asset[]=[
 {id:'hnest',symbol:'hNEST',name:'HyperLeaf hNEST',kind:'erc20',chain:'hyperEVM',address:'0x2101621F51D7E05518D6680C62d04Ad47bC4e05D',price:'none'},
 {id:'nest',symbol:'NEST',name:'NEST',kind:'erc20',chain:'robinhood',address:'0x07c57E32a3C29D5659bda1d3EFC2E7BF004E3035',price:'dexscreener'},
 {id:'bluai4y',symbol:'BLUAI4Y',name:'HyperLeaf BLUAI 4Y',kind:'erc20',chain:'bsc',price:'none'},
 {id:'bluai',symbol:'BLUAI',name:'Bluwhale AI',kind:'erc20',chain:'bsc',address:'0xed9ae3def8d6f052971bb8b6d1975ff267cf9aad',price:'dexscreener'},
 {id:'hkaito',symbol:'hKAITO',name:'HyperLeaf hKAITO',kind:'erc20',chain:'base',price:'none'},
 {id:'hsquid',symbol:'hxSQUID',name:'HyperLeaf hxSQUID',kind:'erc20',chain:'base',price:'none'},
 {id:'hwsteth',symbol:'hwstETH',name:'HyperLeaf hwstETH',kind:'erc20',chain:'ethereum',price:'none'},
 {id:'hvirtualmax',symbol:'hVIRTUALMAX',name:'HyperLeaf hVIRTUALMAX',kind:'erc20',chain:'base',price:'none'},
 {id:'hshmon',symbol:'hshMON',name:'HyperLeaf hshMON',kind:'erc20',chain:'berachain',price:'none'},
 {id:'bera',symbol:'BERA',name:'Berachain',kind:'native',chain:'berachain',price:'coingecko'},
 {id:'bonk12m',symbol:'BONK12M',name:'HyperLeaf BONK 12M',kind:'erc20',chain:'base',price:'none'},
 {id:'hmet',symbol:'hMET',name:'HyperLeaf hMET',kind:'erc20',chain:'base',price:'none'}
];
