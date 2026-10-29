({
    doInit : function(component, event, helper) {
        // PageReference se recordId get karein jab tab me navigate ho
        var pageRef = component.get("v.pageReference");
        if (pageRef && pageRef.state && pageRef.state.c__recordId) {
            component.set("v.recordId", pageRef.state.c__recordId);
        } else if (!component.get("v.recordId") && pageRef && pageRef.attributes) {
            component.set("v.recordId", pageRef.attributes.recordId);
        }
    },

    handleClose : function(component, event, helper) {
        // Tab close hone par wapas record detail page par le jaane ke liye
        var recordId = component.get("v.recordId");
        var navEvt = $A.get("e.force:navigateToSObject");
        if (navEvt && recordId) {
            navEvt.setParams({
                "recordId": recordId,
                "slideDevName": "detail"
            });
            navEvt.fire();
        }
    }
})