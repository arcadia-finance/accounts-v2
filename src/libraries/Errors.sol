/**
 * Created by Pragma Labs
 * SPDX-License-Identifier: BUSL-1.1
 */
pragma solidity 0.8.19;

library AccountErrors {
    error Account_Not_Liquidatable();
    error Account_Unhealthy();
    error Action_Not_Allowed();
    error Already_Initialized();
    error BaseCurrency_Not_Found();
    error Creditor_Already_Set();
    error Creditor_Not_Set();
    error Invalid_Account_Version();
    error Invalid_ERC20_Id();
    error Invalid_ERC721_Amount();
    error Invalid_Recipient();
    error Invalid_Registry();
    error No_Fallback();
    error No_Reentry();
    error NonZero_Open_Position();
    error Only_Factory();
    error Only_Liquidator();
    error Only_Owner();
    error Too_Many_Assets();
    error Unknown_Asset();
    error Unknown_Asset_Type();
}

library FactoryErrors {
    error Account_Version_Blocked();
    error Invalid_Account_Version();
    error Invalid_Upgrade();
    error Logic_Is_Zero();
    error Only_Account_Owner();
    error Version_Mismatch();
    error Version_Root_Is_Zero();
}

library RegistryErrors {
    error AssetMod_Not_Unique();
    error Asset_Already_In_Registry();
    error Invalid_AssetType();
    error Length_Mismatch();
    error Min_1_Oracle();
    error Only_Account();
    error Only_AssetModule();
    error Only_OracleModule();
    error OracleMod_Not_Unique();
    error Unauthorized();
}
