({
    handleClose : function(component, event, helper) {
        // Close the quick action when the LWC fires the close event
        $A.get("e.force:closeQuickAction").fire();
    }
})