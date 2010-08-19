//
//  Wallpaper.mm
//  Wallpaper
//
//  Created by Public Nuisance on 6/25/09.
//  Copyright __MyCompanyName__ 2009. All rights reserved.
//
//  MobileSubstrate, libsubstrate.dylib, and substrate.h are
//  created and copyrighted by Jay Freeman a.k.a saurik and 
//  are protected by various means of open source licensing.
//
//
#define IH_VERSION "2.0.6-1"
#define HIDLIBPATH "/var/mobile/Library/LibHide/hidden.plist"

#include <substrate.h>
@class SBIconLabel;
//@class SBUIController;
#import <SpringBoard/SBApplicationController.h>
#import <SpringBoard/SBIcon.h>
#import <SpringBoard/SBIconModel.h>
#import <SpringBoard/SBApplicationIcon.h>
#import <SpringBoard/SBUIController.h>
#import <SpringBoard/SBIconController.h>
#import <SpringBoard/SBSearchController.h>
#import <SpringBoard/SBSearchView.h>
#import <SpringBoard/SBPlatformController.h>
#import <SpringBoard/SBIconList.h>

@class SBSearchModel;

#include <time.h>
#include <notify.h>

@interface SBIcon (IconHideExtension)
-(BOOL) IH_isHidden;
@end

@interface SBPlatformController (IconHideExtension)
- (void) IH_setInfo:(id)fp8 forCapability:(id)fp12;

@end

@interface SBIconModel (IconHideExtension)            
-(BOOL)IH_isIconVisible:(id)icon;        
-(BOOL)IH_iconIsVisible:(id)icon;  
-(void)IH_loadAllIcons;
-(void)IH_relayout;
-(void)IH_createIconLists;
-(id)IH_init;
-(void)IH_setVisibilityOfIconsWithVisibleTags: (id)fp8 hiddenTags:(id)fp12;
@end

@interface SBUIController (IconHideExtension)            
-(void) IH_tearDownIconListAndBar;
-(void) IH_finishedFadingInButtonBar;
@end

@interface SBIconController (IconHideExtension)
- (void) IH_finishInstallingIcon;
@end



@protocol IconHideMethods

- (BOOL)isHidden;  //SBIcon
- (NSArray*) allApplications; // SBApplicationController
- (NSString*) bundleIdentifier; // SBapplication.h
- (void)setEnabled:(BOOL)fp8; // SBapplication.h
@end

//*******************************************************************************************************
// Globals
//*******************************************************************************************************
NSMutableArray*	global_HiddenIconIds = nil;
NSMutableArray*	global_HiddenSpotlightIconIds = nil;
NSMutableArray*	global_MutableArrayOfApps = nil;
bool				global_Rehide = YES;
bool				global_FirstLoad = YES;
float				global_SystemVersion = 3.0;
SBSearchController* global_SearchController = nil;
bool				global_switcherShowing = NO;

#define SYS_VER_2(_x) (_x >= 2.0 && _x < 3.0) ? YES : NO
#define SYS_VER_3(_x) (_x >= 3.0 && _x < 4.0) ? YES : NO
#define SYS_VER_4(_x) (_x >= 4.0 && _x < 5.0) ? YES : NO

//*******************************************************************************************************
// Prototypes
//*******************************************************************************************************
void* MSHookIvar(id self, const char *unitName) ;
void IconHide_InsertIconIntoSpringboard(NSString* displayId);


//*******************************************************************************************************
// #defines
//*******************************************************************************************************
#define _release(object) \
do if (object != nil) { \
[object release]; \
object = nil; \
} while (false)

#define NSLine() NSLog(@"%s %s %d", __FILE__, __FUNCTION__, __LINE__)
#define HookLog(); \
{ \
uint32_t bt; \
__asm__("mov %0, lr": "=r"(bt)); \
NSLog(@"[%@ %s] bt=%x", [[self class] description], sel_getName(sel), bt); \
}

#define WBPrefix "IH_"

#pragma mark Hooked SpringBoard messages
#pragma mark 

//*******************************************************************************************************
//*******************************************************************************************************
void* MSHookIvar(id self, const char *unitName) 
{
    Ivar ivar =  class_getInstanceVariable(object_getClass(self), unitName);
    void *pointer = (ivar == NULL ? NULL : (char*)(self) + ivar_getOffset(ivar));
    return pointer;
}

//*******************************************************************************************************
// The main rename function for mobile substrate
//*******************************************************************************************************
void IconHideRename(bool instance, const char *classname, const char *oldname, IMP newimp) 
{
    NSLog(@"LibHide: Renaming %s::%s", classname, oldname);
    Class _class = objc_getClass(classname);
    if (_class == nil)
	{
		NSLog(@"LibHide: Warning: cannot find class [%s]", classname);
        return;
    }
    if (!instance)
        _class = object_getClass(_class);
    Method method = class_getInstanceMethod(_class, sel_getUid(oldname));
    if (method == nil) {
		NSLog(@"LibHide: Warning: cannot find method [%s %s]", classname, oldname);
        return;
    }
    size_t namelen = strlen(oldname);
    char newname[sizeof(WBPrefix) + namelen];
    memcpy(newname, WBPrefix, sizeof(WBPrefix) - 1);
    memcpy(newname + sizeof(WBPrefix) - 1, oldname, namelen + 1);
    const char *type = method_getTypeEncoding(method);
    if (!class_addMethod(_class, sel_registerName(newname), method_getImplementation(method), type))
        NSLog(@"LibHide: Error: failed to rename [%s %s]", classname, oldname);
    unsigned int count;
    Method *methods = class_copyMethodList(_class, &count);
    unsigned int index;
    for (index = 0; index != count; ++index)
        if (methods[index] == method)
            goto found;
    if (newimp != NULL)
        if (!class_addMethod(_class, sel_getUid(oldname), newimp, type))
            NSLog(@"LibHide: Error: failed to rename [%s %s]", classname, oldname);
    goto done;
found:
    if (newimp != NULL)
        method_setImplementation(method, newimp);
    NSLog(@"LibHide: Rename success");
done:
    free(methods);
}

#pragma mark dylib initialization and initial hooks
#pragma mark 

//*******************************************************************************************************
// 2.x renamed function
//*******************************************************************************************************
BOOL IconHide_iconIsVisible(SBIconModel *self, SEL sel, id iconId)
{
	BOOL isVisible = [self IH_iconIsVisible:iconId];
	SBApplicationIcon* icon = (SBApplicationIcon*) iconId;
	
	if(global_HiddenIconIds != nil)
	{
		if([global_HiddenIconIds containsObject:[icon displayIdentifier]])
		{
			isVisible = NO;
		}
	}
	return isVisible;	
}

//*******************************************************************************************************
//*******************************************************************************************************
id IconHide_SBSearchController_init(id self, SEL sel)
{
	id newSearchController = [self IH_init];
	
	global_SearchController = newSearchController;
	
	return newSearchController;
}

//*******************************************************************************************************
//*******************************************************************************************************
void IconHide__toggleSwitcher(id self, SEL sel)
{
	global_switcherShowing = YES;
	[self IH__toggleSwitcher];
}

//*******************************************************************************************************
//*******************************************************************************************************
void IconHide_dismissSwitcher(id self, SEL sel)
{
	global_switcherShowing = NO;
	[self IH_dismissSwitcher];
}

//*******************************************************************************************************
//*******************************************************************************************************
BOOL IconHide_isHidden(SBIcon* self, SEL sel)
{
	BOOL Hidden = NO;
	
	if([self respondsToSelector:@selector(leafIdentifier)] && [global_HiddenIconIds containsObject:[self leafIdentifier]])
	{
		Hidden = NO;
	}
	else
	{
		Hidden = [self IH_isHidden];
	}
	
	return Hidden;
}

//*******************************************************************************************************
// 3.x renamed function
//*******************************************************************************************************
BOOL IconHide_isIconVisible(SBIconModel *self, SEL sel, id iconId)
{
	BOOL isVisible = YES;
	BOOL isShowingSearch = NO;
	SBApplicationIcon* icon = (SBApplicationIcon*) iconId;

	if(global_switcherShowing == NO)
	{
		if(SYS_VER_3(global_SystemVersion))
		{
			Class SBSearchController = objc_getClass("SBSearchController");
			SBSearchController* searchController = [SBSearchController sharedInstance];
			if(searchController != nil)
			{
				SBSearchView* SearchView = [searchController searchView];
				if(SearchView != nil)
				{
					isShowingSearch = [SearchView isKeyboardVisible];
				}
			}
		}
		else if(SYS_VER_4(global_SystemVersion))
		{
			//return [self IH_isIconVisible:iconId];
			if(global_SearchController != nil)
			{
				SBSearchView* SearchView = [global_SearchController searchView];
				if(SearchView != nil)
				{
					isShowingSearch = [SearchView isKeyboardVisible];
				}
			}
		}
		else 
		{
			Class SBSearchModel = objc_getClass("SBSearchModel");
			SBSearchModel* searchModel = [SBSearchModel sharedInstance];
			if(searchModel != nil)
			{
				isShowingSearch = [searchModel hasQueryString];
			}
		}

		if(isShowingSearch == NO)
		{
			isVisible = [self IH_isIconVisible:iconId];
			
			if(global_HiddenIconIds != nil)
			{
				if(SYS_VER_3(global_SystemVersion))
				{
					//NSLog(@"Icon: %@", [icon displayIdentifier]);
					if([global_HiddenIconIds containsObject:[icon displayIdentifier]])
					{
						isVisible = NO;
					}
				}
				else
				{
					//NSLog(@"LibHide: %@", [icon leafIdentifier]);
					if([icon respondsToSelector:@selector(leafIdentifier)] &&  
					   [global_HiddenIconIds containsObject:[icon leafIdentifier]])
					{
						isVisible = NO;
					}
				}

			}
		}
		
		// Check for hidden in spotlight key
		else if(global_HiddenSpotlightIconIds != nil)
		{
			if(SYS_VER_3(global_SystemVersion))
			{
				if([global_HiddenSpotlightIconIds containsObject:[icon displayIdentifier]])
				{
					isVisible = NO;
				}
			}
			else
			{
				if([icon respondsToSelector:@selector(leafIdentifier)] &&
				   [global_HiddenSpotlightIconIds containsObject:[icon leafIdentifier]])
				{
					isVisible = NO;
				}
			}
		}
	}
	
	if([icon respondsToSelector:@selector(leafIdentifier)])
	{
	   if([[icon leafIdentifier] isEqualToString: @"com.apple.AdSheet"] || 
		  [[icon leafIdentifier] isEqualToString: @"com.apple.DemoApp"] ||
		  [[icon leafIdentifier] isEqualToString: @"com.apple.iphoneos.iPodOut"] ||
		  [[icon leafIdentifier] isEqualToString: @"com.apple.TrustMe"] ||
		  [[icon leafIdentifier] isEqualToString: @"com.apple.webapp"] ||
		  [[icon leafIdentifier] isEqualToString: @"com.apple.WebSheet"] ||
		  [[icon leafIdentifier] isEqualToString: @"com.apple.nike"] )
	   {
		   isVisible = [self IH_isIconVisible:iconId];
	   }
	}
	
	return isVisible;
}



//*******************************************************************************************************
// LoadHiddenIconList
//*******************************************************************************************************
int LoadHiddenIconList()
{
	int HiddenIcons = 0;
	
	if([[NSFileManager defaultManager] fileExistsAtPath:@HIDLIBPATH])
	{
		NSMutableDictionary* Dict = [NSMutableDictionary dictionaryWithContentsOfFile:@HIDLIBPATH];

		if(global_HiddenIconIds != nil)
		{
			[global_HiddenIconIds release];
		}
		
		global_HiddenIconIds = [[NSMutableArray alloc] initWithArray:[Dict objectForKey:@"Hidden"]];
		if(global_HiddenIconIds != nil)
		{
			if([global_HiddenIconIds containsObject:@"com.apple.mobileipod"])
			{
				[global_HiddenIconIds removeObject:@"com.apple.mobileipod"];
				[global_HiddenIconIds addObject:@"com.apple.mobileipod-MediaPlayer"];
			}
			
			HiddenIcons = [global_HiddenIconIds count];
		}
		
		// This list is for icons to hide from spotlight. 
		global_HiddenSpotlightIconIds = [[NSMutableArray alloc] initWithArray:[Dict objectForKey:@"Spotlight"]];
	}
	
	NSLog(@"LibHide: Returning %d icons hidden", HiddenIcons);
	
	return HiddenIcons;
}

//*******************************************************************************************************
// setInfo - Called for capabilities of app
//*******************************************************************************************************
void IconHide_setInfo(SBPlatformController* self, SEL sel, NSMutableArray* arrayOfApps, NSString* Capability)
{
	if(Capability != nil && [Capability isEqualToString:@"application-display-identifiers"])
	{
		//This assumes arrayOfApps is mutable and not just an NSArray. 
		if(![arrayOfApps respondsToSelector:@selector(addObjectsFromArray:)])
		{
			[arrayOfApps addObjectsFromArray:global_HiddenIconIds];
		}
		
		// In case the array is not mutable.
		else
		{
			NSMutableArray* mutableArray = [NSMutableArray arrayWithArray:arrayOfApps];
			[mutableArray addObjectsFromArray:global_HiddenIconIds];
			arrayOfApps = mutableArray;
		}
	}
	
	[self IH_setInfo:arrayOfApps forCapability:Capability];
}

//*******************************************************************************************************
// This works in 3.0 at least also (maybe 2.0 needs test). 
//*******************************************************************************************************
void IconHide_setVisibilityOfIconsWithVisibleTags(SBIconModel* self, SEL sel, NSArray* visibleTags, NSArray* hiddenTags)
{
	NSMutableArray* iconsToAddToDisplay = [[NSMutableArray alloc] initWithCapacity:10]; 
	
	if(global_HiddenIconIds != nil && global_Rehide == YES)
	{
		NSMutableArray* mutableVisibleTags = [[NSMutableArray alloc] initWithArray: visibleTags];
		NSMutableArray* mutableHiddenTags = [[NSMutableArray alloc] initWithArray: hiddenTags];
		
						 
		global_Rehide = NO;
		
		// Hide all icons that are not yet hidden.
		for(NSString *displayIdentifier in global_HiddenIconIds)
		{
			if([mutableHiddenTags containsObject:displayIdentifier] == NO)
			{
				[mutableHiddenTags addObject:displayIdentifier];
			}
		}
		
		if(global_FirstLoad == NO)
		{
			
			// Unhide anything in hiddenTags that is not in the hidden icons list.
			for(NSString* dId in hiddenTags)
			{
				if([dId isEqualToString:@"com.apple.DemoApp"]) continue;
				if([dId isEqualToString:@"hidden"]) continue;
					
				if([global_HiddenIconIds containsObject:dId] == NO)
				{
					[mutableVisibleTags addObject:dId];
					[mutableHiddenTags removeObject:dId];
					[iconsToAddToDisplay addObject:dId];
				}
			}
		}
		global_FirstLoad = NO;
		[self IH_setVisibilityOfIconsWithVisibleTags:mutableVisibleTags hiddenTags:mutableHiddenTags];
		[mutableVisibleTags release];
		[mutableHiddenTags release];
	}
	else 
	{
		[self IH_setVisibilityOfIconsWithVisibleTags:visibleTags hiddenTags:hiddenTags];
	}

	
	for(NSString* dIdToAdd in	iconsToAddToDisplay)
	{
		IconHide_InsertIconIntoSpringboard(dIdToAdd);
	}
	[iconsToAddToDisplay release];
}

//*******************************************************************************************************
// IconHide_InsertIconIntoSpringboard - Inserts a hidden icon back into springboard.
//*******************************************************************************************************
void IconHide_InsertIconIntoSpringboard(NSString* displayId)
{
	Class SBIconModel = objc_getClass("SBIconModel");
	SBIconModel* iconModel = (SBIconModel*)[SBIconModel sharedInstance];
	
	if(SYS_VER_3(global_SystemVersion))
	{
		SBIcon* icon = [iconModel iconForDisplayIdentifier:displayId];

		bool AddedToPage = NO;
		
		// If Icon is not already placed, place it on springboard.
		if (icon != nil && [iconModel iconListContainingIcon:icon] == nil) 
		{
			[icon setShowsImages:YES];
		
			// Scan for a free slot in one of the icon pages to place the icon.
			for (SBIconList* iconList in [iconModel iconLists]) 
			{
				int x, y;
				if ([iconList firstFreeSlotX:&x Y:&y]) 
				{
					[iconList placeIcon:icon atX:x Y:y animate:NO moveNow:YES];
					AddedToPage = YES;
					break;
				}
			}
			
			// If no slot existed, try to add a free page and place the icon at the top of that page.
			if(AddedToPage == NO)
			{
				[[iconModel addEmptyIconList] placeIcon:icon atX:0 Y:0 animate:NO moveNow:YES];
			}
		}
	}
	else 
	{
		[iconModel addIcon: [iconModel leafIconForIdentifier:displayId]];
	}

	
}

//*******************************************************************************************************
// IconHide_HiddenIconsChanged - Runs when the nofify_post(com.libhide.hiddeniconschanged) is called.
//*******************************************************************************************************
static void IconHide_HiddenIconsChanged(CFNotificationCenterRef center,
											  void *observer,
											  CFStringRef name,
											  const void *object,
											  CFDictionaryRef info
											  )
{
	if([[[UIDevice currentDevice] systemVersion] hasPrefix:@"2."])
	{
		UIApplication* theApp = [UIApplication sharedApplication];
		if([theApp respondsToSelector:@selector(relaunchSpringBoard)])
		{
			[theApp relaunchSpringBoard];
		}
	}

	else 
	{
		LoadHiddenIconList();
		
		Class SBIconModel = objc_getClass("SBIconModel");
		SBIconModel* iconModel = (SBIconModel*)[SBIconModel sharedInstance];
		NSSet** _visibleIconTags = (NSSet**)MSHookIvar(iconModel, "_visibleIconTags");
		NSSet** _hiddenIconTags  = (NSSet**)MSHookIvar(iconModel, "_hiddenIconTags");
		if(*_visibleIconTags != NULL && *_hiddenIconTags != NULL)
		{
			global_Rehide = YES;
			NSArray* visibleIconTags = [*_visibleIconTags allObjects];
			NSArray* hiddenIconTags = [*_hiddenIconTags allObjects];
			[iconModel setVisibilityOfIconsWithVisibleTags:visibleIconTags  hiddenTags:hiddenIconTags];
		}
	}

}

//*******************************************************************************************************
//*******************************************************************************************************
float getSystemVersion()
{
	float Version = 4.0;
	
	if([[NSFileManager defaultManager] fileExistsAtPath:@"/System/Library/CoreServices/SystemVersion.plist"])
	{
		NSMutableDictionary* Dict = [NSMutableDictionary dictionaryWithContentsOfFile:@"/System/Library/CoreServices/SystemVersion.plist"];
		
		NSLog(@"LibHide: Querying system version");
		Version = [[Dict objectForKey:@"ProductVersion"] floatValue];
	}
	
	NSLog(@"LibHide: returning version %f", Version);
	
	return Version;
}

//*******************************************************************************************************
// dylib initializer or entry point.
//*******************************************************************************************************
extern "C" void iconhideInitialize()
{	
   NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];	
	
	NSLog(@"LibHide: v" IH_VERSION " initializer");
	
	global_SystemVersion = getSystemVersion();
	
	//Check open application and create hooks here:
	NSString* identifier = [[NSBundle mainBundle] bundleIdentifier];
	if([identifier isEqualToString:@"com.apple.springboard"])
	{
		if(LoadHiddenIconList() != 0)
		{
			IconHideRename(YES, "SBUIController",		"_toggleSwitcher",			(IMP)&IconHide__toggleSwitcher); 
			IconHideRename(YES, "SBUIController",		"dismissSwitcher",			(IMP)&IconHide_dismissSwitcher); 
			//IconHideRename(YES, "SBAppSwitcherController",	"viewWillAppear",				(IMP)&IconHide_viewWillAppear); 
			IconHideRename(YES, "SBIconModel",			"isIconVisible:",			(IMP)&IconHide_isIconVisible); // newer
			IconHideRename(YES, "SBIconModel",			"iconIsVisible:",			(IMP)&IconHide_iconIsVisible); // older
			IconHideRename(YES, "SBPlatformController",	"setInfo:forCapability:",	(IMP)&IconHide_setInfo);
			//IconHideRename(YES, "SBIcon",				"isHidden",					(IMP)&IconHide_isHidden);
		}
		IconHideRename(YES, "SBSearchController",	"init",	(IMP)&IconHide_SBSearchController_init);
		
		// Set the rehide flag for setVisibilityOfIcons* function.
		global_Rehide = YES;
		global_FirstLoad = YES;
		//IconHideRename(YES, "SBIconModel",		"setVisibilityOfIconsWithVisibleTags:hiddenTags:", (IMP)&IconHide_setVisibilityOfIconsWithVisibleTags);
	}

	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
										 NULL, 
										 &IconHide_HiddenIconsChanged, 
										 (CFStringRef) @"com.libhide.hiddeniconschanged", 
										 NULL, 
										 CFNotificationSuspensionBehaviorDeliverImmediately);	
	
	NSLog(@"LibHide: initializer completed and you're not in safe mode!");

	[pool release];
}


#pragma mark ******* NO LONGER USED *******
//*******************************************************************************************************
//*******************************************************************************************************
//*******************************************************************************************************
//// NO LONGER USED STUFF HERE FOR NOTES:
//*******************************************************************************************************
//*******************************************************************************************************
//*******************************************************************************************************
#if 0

//IconHideRename(YES, "SBIconModel",		"relayout",				(IMP)&IconHide_relayout);
//IconHideRename(YES, "SBIconModel",		"setVisibilityOfIconsWithVisibleTags:hiddenTags:", (IMP)&IconHide_setVisibilityOfIconsWithVisibleTags);
//IconHideRename(YES, "SBIconModel",		"init",					(IMP)&IconHide_init);

//*******************************************************************************************************
// IconHide_init - alternate method to hide all icons. More efficient, but no per request tracking.
//*******************************************************************************************************
id IconHide_init(SBIconModel* self, SEL sel)
{
	id initted = [self IH_init];
	int i;
	
	if(initted)
	{
		NSLog(@"LibHide: SBIconModel init");
		SBApplicationIcon* icon = nil;
		for(i = 0; i < [global_HiddenIconIds count]; i++)
		{
			icon = [self iconForDisplayIdentifier:[global_HiddenIconIds objectAtIndex:i]];
			if(icon)
			{
				NSMutableArray* tags = [NSMutableArray arrayWithArray:[[icon application] tags]];
				[tags addObject:@"hidden"];
				[[icon application] setTags:tags];
			}
		}
	}
	
	return initted;
}

//*******************************************************************************************************
// IconHide_init - alternate method to hide all icons. More efficient, but no per request tracking.
//*******************************************************************************************************
void IconHide_relayout(SBIconModel* self, SEL sel)
{
	if(global_AppsHidden)
	{
		[global_AppsHidden removeAllObjects];
	}
	[self IH_relayout];
}


#endif
