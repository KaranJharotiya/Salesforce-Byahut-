({
    handleClose : function(component, event, helper) {
        // Close the quick action when the LWC fires the close event
        $A.get("e.force:closeQuickAction").fire();
    },

    handleAssigned : function(component, event, helper) {
        // Refresh the record view after owner change, then close the quick action
        $A.get("e.force:refreshView").fire();
        $A.get("e.force:closeQuickAction").fire();
    }
})