pragma solidity 0.4.25;

import "../Essentials/Ownable.sol";


contract Whitelist is Ownable {
    mapping(address => bool) internal investorMap;

    /**
    * event for investor approval logging
    * @param investor approved investor
    */
    event Approved(address indexed investor);

    /**
    * event for investor disapproval logging
    * @param investor disapproved investor
    */
    event Disapproved(address indexed investor);

    constructor(address _owner) 
        public 
        Ownable(_owner) 
    {
        
    }

    /** @param _investor the address of investor to be checked
      * @return true if investor is approved
      */
    function isInvestorApproved(address _investor) external view returns (bool) {
        require(_investor != address(0));
        return investorMap[_investor];
    }

    /** @dev approve an investor
      * @param toApprove investor to be approved
      */
    function approveInvestor(address toApprove) external onlyOwner {
        investorMap[toApprove] = true;
        emit Approved(toApprove);
    }

    /** @dev approve investors in bulk
      * @param toApprove array of investors to be approved
      */
    function approveInvestorsInBulk(address[] toApprove) external onlyOwner {
        for (uint i = 0; i < toApprove.length; i++) {
            investorMap[toApprove[i]] = true;
            emit Approved(toApprove[i]);
        }
    }

    /** @dev disapprove an investor
      * @param toDisapprove investor to be disapproved
      */
    function disapproveInvestor(address toDisapprove) external onlyOwner {
        delete investorMap[toDisapprove];
        emit Disapproved(toDisapprove);
    }

    /** @dev disapprove investors in bulk
      * @param toDisapprove array of investors to be disapproved
      */
    function disapproveInvestorsInBulk(address[] toDisapprove) external onlyOwner {
        for (uint i = 0; i < toDisapprove.length; i++) {
            delete investorMap[toDisapprove[i]];
            emit Disapproved(toDisapprove[i]);
        }
    }
}
