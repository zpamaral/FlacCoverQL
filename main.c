#include <CoreFoundation/CFPlugInCOM.h>
#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#include <QuickLook/QuickLook.h>
#include "FlacCoverQL.h"

#define PLUGIN_ID CFSTR("EF6CEA3B-7D09-4793-BF91-DB6B0B538CEA")

typedef struct __FlacQLPlugin {
    void *interfaceStruct;
    CFUUIDRef factoryID;
    UInt32 refCount;
} FlacQLPlugin;

static HRESULT PluginQueryInterface(void *thisInstance, REFIID iid, LPVOID *ppv);
static ULONG PluginAddRef(void *thisInstance);
static ULONG PluginRelease(void *thisInstance);

static QLGeneratorInterfaceStruct interfaceFtbl = {
    NULL,
    PluginQueryInterface,
    PluginAddRef,
    PluginRelease,
    /* thumbnail callbacks */
    NULL,
    NULL,
    /* preview callbacks */
    GeneratePreviewForURL,
    CancelPreviewGeneration
};

static FlacQLPlugin *AllocPlugin(CFUUIDRef factoryID)
{
    FlacQLPlugin *theNewInstance = malloc(sizeof(FlacQLPlugin));
    if (theNewInstance == NULL) return NULL;

    theNewInstance->interfaceStruct = malloc(sizeof(QLGeneratorInterfaceStruct));
    memcpy(theNewInstance->interfaceStruct, &interfaceFtbl, sizeof(QLGeneratorInterfaceStruct));

    theNewInstance->factoryID = CFRetain(factoryID);
    CFPlugInAddInstanceForFactory(factoryID);
    theNewInstance->refCount = 1;
    return theNewInstance;
}

static void DeallocPlugin(FlacQLPlugin *instance)
{
    CFUUIDRef factoryID = instance->factoryID;
    free(instance->interfaceStruct);
    free(instance);
    if (factoryID) {
        CFPlugInRemoveInstanceForFactory(factoryID);
        CFRelease(factoryID);
    }
}

static HRESULT PluginQueryInterface(void *thisInstance, REFIID iid, LPVOID *ppv)
{
    CFUUIDRef interfaceID = CFUUIDCreateFromUUIDBytes(kCFAllocatorDefault, iid);
    BOOL requested = CFEqual(interfaceID, kQLGeneratorCallbacksInterfaceID);
    CFRelease(interfaceID);

    if (requested) {
        ((QLGeneratorInterfaceStruct *)((FlacQLPlugin *)thisInstance)->interfaceStruct)->AddRef(thisInstance);
        *ppv = thisInstance;
        return S_OK;
    }
    *ppv = NULL;
    return E_NOINTERFACE;
}

static ULONG PluginAddRef(void *thisInstance)
{
    ((FlacQLPlugin *)thisInstance)->refCount++;
    return ((FlacQLPlugin *)thisInstance)->refCount;
}

static ULONG PluginRelease(void *thisInstance)
{
    ((FlacQLPlugin *)thisInstance)->refCount--;
    if (((FlacQLPlugin *)thisInstance)->refCount == 0) {
        DeallocPlugin((FlacQLPlugin *)thisInstance);
        return 0;
    }
    return ((FlacQLPlugin *)thisInstance)->refCount;
}

void *QuickLookGeneratorPluginFactory(CFAllocatorRef allocator, CFUUIDRef typeID)
{
    if (CFEqual(typeID, kQLGeneratorTypeID)) {
        CFUUIDRef uuid = CFUUIDCreateFromString(kCFAllocatorDefault, PLUGIN_ID);
        FlacQLPlugin *result = AllocPlugin(uuid);
        CFRelease(uuid);
        return result;
    }
    return NULL;
}
