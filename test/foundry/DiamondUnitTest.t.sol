// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";

import {ColabX} from "contracts/ColabX.sol";
import {DiamondInit} from "contracts/upgradeInitializers/DiamondInit.sol";

import {DiamondCutFacet} from "contracts/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "contracts/facets/DiamondLoupeFacet.sol";
import {AccessControlFacet} from "contracts/facets/AccessControlFacet.sol";
import {AccessControlFacet} from "contracts/facets/AccessControlFacet.sol";
import {ProjectFactoryFacet} from "contracts/facets/ProjectFactoryFacet.sol";

import {IDiamondCut, FacetCut, FacetCutAction} from "contracts/interfaces/IDiamondCut.sol";
import {IDiamondInit} from "../../contracts/interfaces/IDiamondInit.sol";
import {IDiamondLoupe} from "contracts/interfaces/IDiamondLoupe.sol";
import {IAccessControl} from "contracts/interfaces/IAccessControl.sol";
import {IERC165} from "contracts/interfaces/IERC165.sol";

import {LibDiamond, DiamondArgs} from "contracts/libraries/LibDiamond.sol";

// import {LibApp} from "contracts/libraries/LibApp.sol";
contract DiamondUnitTest is Test {
    ColabX diamond;
    DiamondInit diamondInit;

    DiamondCutFacet diamondCutFacet;
    DiamondLoupeFacet diamondLoupeFacet;
    AccessControlFacet accessControlFacet;
    ProjectFactoryFacet projectFactoryFacet;

    IDiamondLoupe ILoupe;
    IDiamondCut ICut;

    address diamondAdmin = address(0x1337DAD);
    address alice = address(0xA11C3);
    address bob = address(0xB0B);
    address hacker = address(0xBAD);

    address[] facetAddressList;

    function setUp() public {
        // Deploy core diamond template contracts
        diamondInit = new DiamondInit();
        diamondCutFacet = new DiamondCutFacet();
        diamondLoupeFacet = new DiamondLoupeFacet();
        accessControlFacet = new AccessControlFacet();

        DiamondArgs memory initDiamondArgs = DiamondArgs({
            init: address(diamondInit),
            // NOTE: "interfaceId" can be used since "init" is the only function in IDiamondInit.
            initCalldata: abi.encode(type(IDiamondInit).interfaceId)
        });

        FacetCut[] memory initCut = new FacetCut[](3);

        bytes4[] memory initCutSelectors = new bytes4[](1);
        initCutSelectors[0] = IDiamondCut.diamondCut.selector;

        bytes4[] memory loupeSelectors = new bytes4[](5);
        loupeSelectors[0] = IDiamondLoupe.facets.selector;
        loupeSelectors[1] = IDiamondLoupe.facetFunctionSelectors.selector;
        loupeSelectors[2] = IDiamondLoupe.facetAddresses.selector;
        loupeSelectors[3] = IDiamondLoupe.facetAddress.selector;
        loupeSelectors[4] = IERC165.supportsInterface.selector;

        bytes4[] memory accessControlSelectors = new bytes4[](6);
        accessControlSelectors[0] = IAccessControl.hasRole.selector;
        accessControlSelectors[1] = IAccessControl.getRoleAdmin.selector;
        accessControlSelectors[2] = IAccessControl.grantRole.selector;
        accessControlSelectors[3] = IAccessControl.revokeRole.selector;
        accessControlSelectors[4] = IAccessControl.renounceRole.selector;
        accessControlSelectors[5] = AccessControlFacet.setRoleAdmin.selector;

        initCut[0] = FacetCut({
            facetAddress: address(diamondCutFacet),
            action: FacetCutAction.Add,
            functionSelectors: initCutSelectors
        });

        initCut[1] = FacetCut({
            facetAddress: address(diamondLoupeFacet),
            action: FacetCutAction.Add,
            functionSelectors: loupeSelectors
        });

        initCut[2] = FacetCut({
            facetAddress: address(accessControlFacet),
            action: FacetCutAction.Add,
            functionSelectors: accessControlSelectors
        });

        console.log("Diamond Admin: ", address(diamondAdmin));
        console.log("Msg.sender: ", msg.sender);
        // assertEq(address(diamondAdmin), msg.sender, "msg.sender not diamondAdmin");
        diamond = new ColabX(msg.sender, initCut, initDiamondArgs);

        IAccessControl(address(diamond)).grantRole(LibDiamond.DEFAULT_ADMIN_ROLE, msg.sender);
        IAccessControl(address(diamond)).grantRole(LibDiamond.DIAMOND_ADMIN_ROLE, msg.sender);

        facetAddressList = IDiamondLoupe(address(diamond)).facetAddresses(); // save all facet addresses

        // Set interfaces for less verbose diamond interactions.
        ILoupe = IDiamondLoupe(address(diamond));
        ICut = IDiamondCut(address(diamond));
    }

    function test_Deployment() public view {
        // All 3 facets have been added to the diamond, and are not 0x0 address.
        assertEq(facetAddressList.length, 3, "Cut, Loupe, AccessControl");
        assertNotEq(facetAddressList[0], address(0), "Not 0x0 address");
        assertNotEq(facetAddressList[1], address(0), "Not 0x0 address");
        assertNotEq(facetAddressList[2], address(0), "Not 0x0 address");

        // Interface support set to true during `init()` call during Diamond upgrade?
        assertTrue(
            IERC165(address(diamond)).supportsInterface(
                type(IERC165).interfaceId
            ),
            "IERC165"
        );
        assertTrue(
            IERC165(address(diamond)).supportsInterface(
                type(IDiamondCut).interfaceId
            ),
            "Cut"
        );
        assertTrue(
            IERC165(address(diamond)).supportsInterface(
                type(IDiamondLoupe).interfaceId
            ),
            "Loupe"
        );

        // Facets have the correct function selectors?
        bytes4[] memory loupeViewCut = ILoupe.facetFunctionSelectors(
            facetAddressList[0]
        ); // DiamondCut
        bytes4[] memory loupeViewLoupe = ILoupe.facetFunctionSelectors(
            facetAddressList[1]
        ); // Loupe
        bytes4[] memory loupeViewAccessControl = ILoupe.facetFunctionSelectors(
            facetAddressList[2]
        ); // AccessControl

        assertEq(
            loupeViewCut[0],
            IDiamondCut.diamondCut.selector,
            "should match"
        );

        assertEq(
            loupeViewLoupe[0],
            IDiamondLoupe.facets.selector,
            "should match"
        );
        assertEq(
            loupeViewLoupe[1],
            IDiamondLoupe.facetFunctionSelectors.selector,
            "should match"
        );
        assertEq(
            loupeViewLoupe[2],
            IDiamondLoupe.facetAddresses.selector,
            "should match"
        );
        assertEq(
            loupeViewLoupe[3],
            IDiamondLoupe.facetAddress.selector,
            "should match"
        );
        assertEq(
            loupeViewLoupe[4],
            IERC165.supportsInterface.selector,
            "should match"
        );

        assertEq(
            loupeViewAccessControl[0],
            IAccessControl.hasRole.selector,
            "should match"
        );
        assertEq(
            loupeViewAccessControl[1],
            IAccessControl.getRoleAdmin.selector,
            "should match"
        );
        assertEq(
            loupeViewAccessControl[2],
            IAccessControl.grantRole.selector,
            "should match"
        );
        assertEq(
            loupeViewAccessControl[3],
            IAccessControl.revokeRole.selector,
            "should match"
        );
        assertEq(
            loupeViewAccessControl[4],
            IAccessControl.renounceRole.selector,
            "should match"
        );
        assertEq(
            loupeViewAccessControl[5],
            AccessControlFacet.setRoleAdmin.selector,
            "should match"
        );

        // Function selectors are associated with the correct facets?
        assertEq(
            facetAddressList[0],
            ILoupe.facetAddress(IDiamondCut.diamondCut.selector),
            "should match"
        );

        assertEq(
            facetAddressList[1],
            ILoupe.facetAddress(IDiamondLoupe.facets.selector),
            "should match"
        );
        assertEq(
            facetAddressList[1],
            ILoupe.facetAddress(IDiamondLoupe.facetFunctionSelectors.selector),
            "should match"
        );
        assertEq(
            facetAddressList[1],
            ILoupe.facetAddress(IDiamondLoupe.facetAddresses.selector),
            "should match"
        );
        assertEq(
            facetAddressList[1],
            ILoupe.facetAddress(IDiamondLoupe.facetAddress.selector),
            "should match"
        );
        assertEq(
            facetAddressList[1],
            ILoupe.facetAddress(IERC165.supportsInterface.selector),
            "should match"
        );

        assertEq(
            facetAddressList[2],
            ILoupe.facetAddress(IAccessControl.hasRole.selector),
            "should match"
        );
        assertEq(
            facetAddressList[2],
            ILoupe.facetAddress(IAccessControl.getRoleAdmin.selector),
            "should match"
        );
        assertEq(
            facetAddressList[2],
            ILoupe.facetAddress(IAccessControl.grantRole.selector),
            "should match"
        );
        assertEq(
            facetAddressList[2],
            ILoupe.facetAddress(IAccessControl.revokeRole.selector),
            "should match"
        );
        assertEq(
            facetAddressList[2],
            ILoupe.facetAddress(IAccessControl.renounceRole.selector),
            "should match"
        );
        assertEq(
            facetAddressList[2],
            ILoupe.facetAddress(AccessControlFacet.setRoleAdmin.selector),
            "should match"
        );
    }

    function test_addProjectFactoryFacet() public {
        projectFactoryFacet = new ProjectFactoryFacet();

        FacetCut[] memory projectFactoryCut = new FacetCut[](1);

        bytes4[] memory projectFactoryFacetSelectors = new bytes4[](6);
        projectFactoryFacetSelectors[0] = 0x6bd06204;
        projectFactoryFacetSelectors[1] = 0x47c6c99c;
        projectFactoryFacetSelectors[2] = 0xf751cd8f;
        projectFactoryFacetSelectors[3] = 0x429a4365;
        projectFactoryFacetSelectors[4] = 0xd6e403f3;
        projectFactoryFacetSelectors[5] = 0x29e4b44f;

        projectFactoryCut[0] = FacetCut({
            facetAddress: address(projectFactoryFacet),
            action: FacetCutAction.Add,
            functionSelectors: projectFactoryFacetSelectors
        });

        IDiamondCut(address(diamond)).diamondCut(projectFactoryCut, address(0), "");

        assertEq(facetAddressList.length, 4, "Cut, Loupe, AccessControl, ProjectFactory");
    }
}
