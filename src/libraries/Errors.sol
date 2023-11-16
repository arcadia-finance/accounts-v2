/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

library Account {
    error REENTRANCY();
    error Only_Factory();
    error Only_Owner();
    error Only_Liquidator();
    error Already_Initialized();
    error Invalid_Recipient();
    error Invalid_Registry();
    error Invalid_Account_Version();
    error Creditor_Already_Set();
    error Creditor_Not_Set();
    error BaseCurrency_Not_Found();
    error NonZero_Open_Position();
    error Account_Not_Liquidatable();
    error Action_Not_Allowed();
    error Account_Unhealthy();
    error Invalid_ERC20_Id();
    error Invalid_ERC721_Amount();
    error Unknown_Asset_Type();
    error Too_Many_Assets();
    error Unknown_Asset();
    error No_Fallback();
}

library FactoryErrors {
    error Invalid_Account_Version();
    error Account_Version_Blocked();
    error Only_Account_Owner();
    error Invalid_Upgrade();
    error Version_Root_Is_Zero();
    error Logic_Is_Zero();
    error Version_Mismatch();
}

library RegistryErrors {
    error Only_AssetModule();
    error Only_OracleModule();
    error Only_Account();
    error AssetMod_Not_Unique();
    error OracleMod_Not_Unique();
    error Asset_Already_In_Registry();
    error Invalid_AssetType();
    error Min_1_Oracle();
    error Unauthorized();
    error Length_Mismatch();
}
