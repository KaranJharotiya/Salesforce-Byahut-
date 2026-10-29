({
    handleCloseAction : function(component, event, helper) {
        // Close the Quick Action modal
        $A.get("e.force:closeQuickAction").fire();
    }
})