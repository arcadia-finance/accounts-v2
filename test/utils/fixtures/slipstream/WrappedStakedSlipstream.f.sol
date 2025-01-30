/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity ^0.8.22;

import { IWrappedStakedSlipstream } from "./interfaces/IWrappedStakedSlipstream.sol";
import { Utils } from "../../../utils/Utils.sol";
import { Test } from "../../../../lib/forge-std/src/Test.sol";

contract WrappedStakedSlipstreamFixture is Test {
    /*//////////////////////////////////////////////////////////////////////////
                                   CONTRACTS
    //////////////////////////////////////////////////////////////////////////*/

    IWrappedStakedSlipstream internal wrappedStakedSlipstream =
        IWrappedStakedSlipstream(0xD74339e0F10fcE96894916B93E5Cc7dE89C98272);

    /*//////////////////////////////////////////////////////////////////////////
                                     CONSTANTS
    //////////////////////////////////////////////////////////////////////////*/

    bytes internal constant BYTECODE_WRAPPED_STAKED_SLIPSTREAM =
        hex"608060405234801561000f575f5ffd5b5060043610610187575f3560e01c80636c0360eb116100d9578063ae169a5011610093578063daa3770c1161006e578063daa3770c146103b5578063e70dd6cf146103c8578063e985e9c5146103e3578063f2fde38b14610410575f5ffd5b8063ae169a501461037c578063b88d4fde1461038f578063c87b56dd146103a2575f5ffd5b80636c0360eb1461032057806370a08231146103285780638da5cb5b1461033b57806395d89b411461034e578063a0712d6814610356578063a22cb46514610369575f5ffd5b80631bea83fe1161014457806342966c681161011f57806342966c68146102b157806355f804b3146102d25780635b113191146102e55780636352211e1461030d575f5ffd5b80631bea83fe1461027057806323b872dd1461028b57806342842e0e1461029e575f5ffd5b806301ffc9a71461018b57806306fdde03146101b3578063081812fc146101c8578063095ea7b314610208578063150b7a021461021d5780631691bd6f14610255575b5f5ffd5b61019e6101993660046119b4565b610423565b60405190151581526020015b60405180910390f35b6101bb610474565b6040516101aa91906119d6565b6101f06101d6366004611a0b565b60046020525f90815260409020546001600160a01b031681565b6040516001600160a01b0390911681526020016101aa565b61021b610216366004611a36565b6104ff565b005b61023c61022b366004611aa5565b630a85bd0160e11b95945050505050565b6040516001600160e01b031990911681526020016101aa565b6101f073940181a94a35a4569e4529a3cdfb74e38fd9863181565b6101f073827922686190790b37229fd06084350e74485b7281565b61021b610299366004611b13565b6105e3565b61021b6102ac366004611b13565b6107a5565b6102c46102bf366004611a0b565b610876565b6040519081526020016101aa565b61021b6102e0366004611b51565b610ac4565b6101f06102f3366004611a0b565b60096020525f90815260409020546001600160a01b031681565b6101f061031b366004611a0b565b610b1a565b6101bb610b70565b6102c4610336366004611b90565b610b7d565b6006546101f0906001600160a01b031681565b6101bb610bde565b6102c4610364366004611a0b565b610beb565b61021b610377366004611bab565b611052565b6102c461038a366004611a0b565b6110bd565b61021b61039d366004611aa5565b61127a565b6101bb6103b0366004611a0b565b61133c565b6102c46103c3366004611a0b565b611398565b6101f0735e7bb104d84c7cb9b682aac2f3d509f5f406809a81565b61019e6103f1366004611be6565b600560209081525f928352604080842090915290825290205460ff1681565b61021b61041e366004611b90565b611414565b5f6301ffc9a760e01b6001600160e01b03198316148061045357506380ac58cd60e01b6001600160e01b03198316145b8061046e5750635b5e139f60e01b6001600160e01b03198316145b92915050565b5f805461048090611c12565b80601f01602080910402602001604051908101604052809291908181526020018280546104ac90611c12565b80156104f75780601f106104ce576101008083540402835291602001916104f7565b820191905f5260205f20905b8154815290600101906020018083116104da57829003601f168201915b505050505081565b5f818152600260205260409020546001600160a01b03163381148061054657506001600160a01b0381165f90815260056020908152604080832033845290915290205460ff165b6105885760405162461bcd60e51b815260206004820152600e60248201526d1393d517d055551213d49256915160921b60448201526064015b60405180910390fd5b5f8281526004602052604080822080546001600160a01b0319166001600160a01b0387811691821790925591518593918516917f8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b92591a4505050565b5f818152600260205260409020546001600160a01b038481169116146106385760405162461bcd60e51b815260206004820152600a60248201526957524f4e475f46524f4d60b01b604482015260640161057f565b6001600160a01b0382166106825760405162461bcd60e51b81526020600482015260116024820152701253959053125117d49150d25412515395607a1b604482015260640161057f565b336001600160a01b03841614806106bb57506001600160a01b0383165f90815260056020908152604080832033845290915290205460ff165b806106db57505f818152600460205260409020546001600160a01b031633145b6107185760405162461bcd60e51b815260206004820152600e60248201526d1393d517d055551213d49256915160921b604482015260640161057f565b6001600160a01b038084165f81815260036020908152604080832080545f19019055938616808352848320805460010190558583526002825284832080546001600160a01b03199081168317909155600490925284832080549092169091559251849392917fddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef91a4505050565b6107b08383836105e3565b6001600160a01b0382163b15806108555750604051630a85bd0160e11b8082523360048301526001600160a01b03858116602484015260448301849052608060648401525f608484015290919084169063150b7a029060a4016020604051808303815f875af1158015610825573d5f5f3e3d5ffd5b505050506040513d601f19601f820116820180604052508101906108499190611c4a565b6001600160e01b031916145b6108715760405162461bcd60e51b815260040161057f90611c65565b505050565b5f6007546001146108995760405162461bcd60e51b815260040161057f90611c8f565b600260078190555f83815260209190915260409020546001600160a01b031633146108d7576040516330cd747160e01b815260040160405180910390fd5b5f8281526009602052604090819020549051632e1a7d4d60e01b8152600481018490526001600160a01b0390911690632e1a7d4d906024015f604051808303815f87803b158015610926575f5ffd5b505af1158015610938573d5f5f3e3d5ffd5b50506040516370a0823160e01b815230600482015273940181a94a35a4569e4529a3cdfb74e38fd9863192506370a082319150602401602060405180830381865afa158015610989573d5f5f3e3d5ffd5b505050506040513d601f19601f820116820180604052508101906109ad9190611cb3565b5f83815260096020526040902080546001600160a01b031916905590506109d3826114a8565b8015610a4d576109f873940181a94a35a4569e4529a3cdfb74e38fd986313383611572565b6040516001600160801b038216815273940181a94a35a4569e4529a3cdfb74e38fd986319083907f99eb7ece63bef2ec97b991da7cf3763c7c533b1614782a4afd1b7b028db3189f9060200160405180910390a35b604051632142170760e11b81523060048201523360248201526044810183905273827922686190790b37229fd06084350e74485b72906342842e0e906064015f604051808303815f87803b158015610aa3575f5ffd5b505af1158015610ab5573d5f5f3e3d5ffd5b50506001600755509092915050565b6006546001600160a01b03163314610b0d5760405162461bcd60e51b815260206004820152600c60248201526b15539055551213d49256915160a21b604482015260640161057f565b6008610871828483611d22565b5f818152600260205260409020546001600160a01b031680610b6b5760405162461bcd60e51b815260206004820152600a6024820152691393d517d3525395115160b21b604482015260640161057f565b919050565b6008805461048090611c12565b5f6001600160a01b038216610bc35760405162461bcd60e51b815260206004820152600c60248201526b5a45524f5f4144445245535360a01b604482015260640161057f565b506001600160a01b03165f9081526003602052604090205490565b6001805461048090611c12565b5f600754600114610c0e5760405162461bcd60e51b815260040161057f90611c8f565b6002600755604051632142170760e11b81523360048201523060248201526044810183905273827922686190790b37229fd06084350e74485b72906342842e0e906064015f604051808303815f87803b158015610c69575f5ffd5b505af1158015610c7b573d5f5f3e3d5ffd5b505060405163133f757160e31b8152600481018590525f9250829150819073827922686190790b37229fd06084350e74485b72906399fbab889060240161018060405180830381865afa158015610cd4573d5f5f3e3d5ffd5b505050506040513d601f19601f82011682018060405250810190610cf89190611e0e565b5050505050505094509450945050505f610d3d73ec8e5342b19977b4ef8892e02d8daecfa1315831735e7bb104d84c7cb9b682aac2f3d509f5f406809a8686866115f5565b90505f816001600160a01b031663a6f19c846040518163ffffffff1660e01b8152600401602060405180830381865afa158015610d7c573d5f5f3e3d5ffd5b505050506040513d601f19601f82011682018060405250810190610da09190611ee8565b5f8881526009602090815260409182902080546001600160a01b0319166001600160a01b038516908117909155825163f7c618c160e01b8152925193945073940181a94a35a4569e4529a3cdfb74e38fd9863193909263f7c618c19260048083019391928290030181865afa158015610e1b573d5f5f3e3d5ffd5b505050506040513d601f19601f82011682018060405250810190610e3f9190611ee8565b6001600160a01b031614610e6657604051633616e34b60e11b815260040160405180910390fd5b60405163095ea7b360e01b81526001600160a01b03821660048201526024810188905273827922686190790b37229fd06084350e74485b729063095ea7b3906044015f604051808303815f87803b158015610ebf575f5ffd5b505af1158015610ed1573d5f5f3e3d5ffd5b505060405163b6b55f2560e01b8152600481018a90526001600160a01b038416925063b6b55f2591506024015f604051808303815f87803b158015610f14575f5ffd5b505af1158015610f26573d5f5f3e3d5ffd5b50506040516370a0823160e01b81523060048201525f92506001600160a01b03881691506370a0823190602401602060405180830381865afa158015610f6e573d5f5f3e3d5ffd5b505050506040513d601f19601f82011682018060405250810190610f929190611cb3565b6040516370a0823160e01b81523060048201529091505f906001600160a01b038716906370a0823190602401602060405180830381865afa158015610fd9573d5f5f3e3d5ffd5b505050506040513d601f19601f82011682018060405250810190610ffd9190611cb3565b90508115611019576110196001600160a01b0388163384611572565b8015611033576110336001600160a01b0387163383611572565b889750611040338a6116c2565b50506001600755509395945050505050565b335f8181526005602090815260408083206001600160a01b03871680855290835292819020805460ff191686151590811790915590519081529192917f17307eab39ab6107e8899845ad3d59bd9653f200f220920489ca2b5937696c31910160405180910390a35050565b5f6007546001146110e05760405162461bcd60e51b815260040161057f90611c8f565b600260078190555f83815260209190915260409020546001600160a01b0316331461111e576040516330cd747160e01b815260040160405180910390fd5b5f8281526009602052604090819020549051631c4b774b60e01b8152600481018490526001600160a01b0390911690631c4b774b906024015f604051808303815f87803b15801561116d575f5ffd5b505af115801561117f573d5f5f3e3d5ffd5b50506040516370a0823160e01b815230600482015273940181a94a35a4569e4529a3cdfb74e38fd9863192506370a082319150602401602060405180830381865afa1580156111d0573d5f5f3e3d5ffd5b505050506040513d601f19601f820116820180604052508101906111f49190611cb3565b905080156112705761121b73940181a94a35a4569e4529a3cdfb74e38fd986313383611572565b6040516001600160801b038216815273940181a94a35a4569e4529a3cdfb74e38fd986319083907f99eb7ece63bef2ec97b991da7cf3763c7c533b1614782a4afd1b7b028db3189f9060200160405180910390a35b6001600755919050565b6112858585856105e3565b6001600160a01b0384163b15806113195750604051630a85bd0160e11b808252906001600160a01b0386169063150b7a02906112cd9033908a90899089908990600401611f03565b6020604051808303815f875af11580156112e9573d5f5f3e3d5ffd5b505050506040513d601f19601f8201168201806040525081019061130d9190611c4a565b6001600160e01b031916145b6113355760405162461bcd60e51b815260040161057f90611c65565b5050505050565b60605f6008805461134c90611c12565b9050116113675760405180602001604052805f81525061046e565b60086113728361178e565b604051602001611383929190611f53565b60405160208183030381529060405292915050565b5f81815260096020526040808220549051633e491d4760e01b8152306004820152602481018490526001600160a01b0390911690633e491d4790604401602060405180830381865afa1580156113f0573d5f5f3e3d5ffd5b505050506040513d601f19601f8201168201806040525081019061046e9190611cb3565b6006546001600160a01b0316331461145d5760405162461bcd60e51b815260206004820152600c60248201526b15539055551213d49256915160a21b604482015260640161057f565b600680546001600160a01b0319166001600160a01b03831690811790915560405133907f8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e0905f90a350565b5f818152600260205260409020546001600160a01b0316806114f95760405162461bcd60e51b815260206004820152600a6024820152691393d517d3525395115160b21b604482015260640161057f565b6001600160a01b0381165f81815260036020908152604080832080545f190190558583526002825280832080546001600160a01b031990811690915560049092528083208054909216909155518492907fddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef908390a45050565b5f60405163a9059cbb60e01b81526001600160a01b038416600482015282602482015260205f6044835f895af13d15601f3d1160015f5114161716915050806115ef5760405162461bcd60e51b815260206004820152600f60248201526e1514905394d1915497d19052531151608a1b604482015260640161057f565b50505050565b5f826001600160a01b0316846001600160a01b031610611613575f5ffd5b604080516001600160a01b038087166020830152851691810191909152600283900b60608201526116b89087906080016040516020818303038152906040528051906020012087604051733d602d80600a3d3981f3363d3d373d3d3d363d7360601b8152606093841b60148201526f5af43d82803e903d91602b57fd5bf3ff60801b6028820152921b6038830152604c8201526037808220606c830152605591012090565b9695505050505050565b6116cc8282611893565b6001600160a01b0382163b158061176e5750604051630a85bd0160e11b8082523360048301525f6024830181905260448301849052608060648401526084830152906001600160a01b0384169063150b7a029060a4016020604051808303815f875af115801561173e573d5f5f3e3d5ffd5b505050506040513d601f19601f820116820180604052508101906117629190611c4a565b6001600160e01b031916145b61178a5760405162461bcd60e51b815260040161057f90611c65565b5050565b6060815f036117b45750506040805180820190915260018152600360fc1b602082015290565b815f5b81156117dd57806117c781611fe7565b91506117d69050600a83612013565b91506117b7565b5f8167ffffffffffffffff8111156117f7576117f7611cca565b6040519080825280601f01601f191660200182016040528015611821576020820181803683370190505b5090505b841561188b57611836600183612026565b9150611843600a86612039565b61184e90603061204c565b60f81b8183815181106118635761186361205f565b60200101906001600160f81b03191690815f1a905350611884600a86612013565b9450611825565b949350505050565b6001600160a01b0382166118dd5760405162461bcd60e51b81526020600482015260116024820152701253959053125117d49150d25412515395607a1b604482015260640161057f565b5f818152600260205260409020546001600160a01b0316156119325760405162461bcd60e51b815260206004820152600e60248201526d1053149150511657d3525395115160921b604482015260640161057f565b6001600160a01b0382165f81815260036020908152604080832080546001019055848352600290915280822080546001600160a01b0319168417905551839291907fddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef908290a45050565b6001600160e01b0319811681146119b1575f5ffd5b50565b5f602082840312156119c4575f5ffd5b81356119cf8161199c565b9392505050565b602081525f82518060208401528060208501604085015e5f604082850101526040601f19601f83011684010191505092915050565b5f60208284031215611a1b575f5ffd5b5035919050565b6001600160a01b03811681146119b1575f5ffd5b5f5f60408385031215611a47575f5ffd5b8235611a5281611a22565b946020939093013593505050565b5f5f83601f840112611a70575f5ffd5b50813567ffffffffffffffff811115611a87575f5ffd5b602083019150836020828501011115611a9e575f5ffd5b9250929050565b5f5f5f5f5f60808688031215611ab9575f5ffd5b8535611ac481611a22565b94506020860135611ad481611a22565b935060408601359250606086013567ffffffffffffffff811115611af6575f5ffd5b611b0288828901611a60565b969995985093965092949392505050565b5f5f5f60608486031215611b25575f5ffd5b8335611b3081611a22565b92506020840135611b4081611a22565b929592945050506040919091013590565b5f5f60208385031215611b62575f5ffd5b823567ffffffffffffffff811115611b78575f5ffd5b611b8485828601611a60565b90969095509350505050565b5f60208284031215611ba0575f5ffd5b81356119cf81611a22565b5f5f60408385031215611bbc575f5ffd5b8235611bc781611a22565b915060208301358015158114611bdb575f5ffd5b809150509250929050565b5f5f60408385031215611bf7575f5ffd5b8235611c0281611a22565b91506020830135611bdb81611a22565b600181811c90821680611c2657607f821691505b602082108103611c4457634e487b7160e01b5f52602260045260245ffd5b50919050565b5f60208284031215611c5a575f5ffd5b81516119cf8161199c565b60208082526010908201526f155394d0519157d49150d2541251539560821b604082015260600190565b6020808252600a90820152695245454e5452414e435960b01b604082015260600190565b5f60208284031215611cc3575f5ffd5b5051919050565b634e487b7160e01b5f52604160045260245ffd5b601f82111561087157805f5260205f20601f840160051c81016020851015611d035750805b601f840160051c820191505b81811015611335575f8155600101611d0f565b67ffffffffffffffff831115611d3a57611d3a611cca565b611d4e83611d488354611c12565b83611cde565b5f601f841160018114611d7f575f8515611d685750838201355b5f19600387901b1c1916600186901b178355611335565b5f83815260208120601f198716915b82811015611dae5786850135825560209485019460019092019101611d8e565b5086821015611dca575f1960f88860031b161c19848701351681555b505060018560011b0183555050505050565b8051610b6b81611a22565b8051600281900b8114610b6b575f5ffd5b80516001600160801b0381168114610b6b575f5ffd5b5f5f5f5f5f5f5f5f5f5f5f5f6101808d8f031215611e2a575f5ffd5b8c516bffffffffffffffffffffffff81168114611e45575f5ffd5b9b50611e5360208e01611ddc565b9a50611e6160408e01611ddc565b9950611e6f60608e01611ddc565b9850611e7d60808e01611de7565b9750611e8b60a08e01611de7565b9650611e9960c08e01611de7565b9550611ea760e08e01611df8565b6101008e01516101208f015191965094509250611ec76101408e01611df8565b9150611ed66101608e01611df8565b90509295989b509295989b509295989b565b5f60208284031215611ef8575f5ffd5b81516119cf81611a22565b6001600160a01b03868116825285166020820152604081018490526080606082018190528101829052818360a08301375f81830160a090810191909152601f909201601f19160101949350505050565b5f5f8454611f6081611c12565b600182168015611f775760018114611f8c57611fb9565b60ff1983168652811515820286019350611fb9565b875f5260205f205f5b83811015611fb157815488820152600190910190602001611f95565b505081860193505b50505083518060208601835e5f9101908152949350505050565b634e487b7160e01b5f52601160045260245ffd5b5f60018201611ff857611ff8611fd3565b5060010190565b634e487b7160e01b5f52601260045260245ffd5b5f8261202157612021611fff565b500490565b8181038181111561046e5761046e611fd3565b5f8261204757612047611fff565b500690565b8082018082111561046e5761046e611fd3565b634e487b7160e01b5f52603260045260245ffdfea26469706673582212202f7386b66f9a68b7a7414d67e9fad8bf37681dba9552fff563407b4e15080f8864736f6c634300081b0033";

    /*//////////////////////////////////////////////////////////////////////////
                                     WETH9
    //////////////////////////////////////////////////////////////////////////*/

    function setUp() public virtual {
        address wrappedStakedSlipstream_ = Utils.deployBytecode(BYTECODE_WRAPPED_STAKED_SLIPSTREAM);
        vm.etch(address(wrappedStakedSlipstream), wrappedStakedSlipstream_.code);
        (bool success, bytes memory runtimeBytecode) = wrappedStakedSlipstream_.call{ value: 0 }("");
        require(success, "Failed to create runtime bytecode.");
        vm.etch(address(wrappedStakedSlipstream), runtimeBytecode);
    }
}
