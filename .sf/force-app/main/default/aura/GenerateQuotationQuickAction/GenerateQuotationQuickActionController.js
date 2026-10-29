({
    handleClose : function(component, event, helper) {
        // LWC se close event aane par quick action band karein
        $A.get("e.force:closeQuickAction").fire();
    }
})