// PlistPath is the full path to the app's Info.plist file for example:
// /Applications/MobileSafari.app/Info.plist
//
// There are exceptions allowed for camera and photos. You should use these:
// /Applications/Camera.app/Info.plist
// /Applications/Photos.app/Info.plist
//
//*************************************************************************************************
// IsIconHidden - Determines if the icon passed in is already hidden or not.
//*************************************************************************************************
BOOL IsIconHidden(NSString* PlistPath)
{
	BOOL Hidden = NO;
		
	void* libHandle = dlopen("/usr/lib/hide.dylib", RTLD_LAZY);
	
	if(libHandle != NULL) 
	{
		BOOL (*IsIconHidden)(NSString* Plist) = dlsym(libHandle, "IsIconHidden");
		if(IsIconHidden != NULL)
		{
			Hidden = IsIconHidden(PlistPath);
		}
	}
	
	if(libHandle != NULL) dlclose(libHandle);
	
	return Hidden;
}

//*************************************************************************************************
// HideIcon - Hides the icon at the path passed in.
//*************************************************************************************************
BOOL HideIcon(NSString* PlistPath)
{
	
	NSLog(@"Hiding %@\n", PlistPath);
	void* libHandle = dlopen("/usr/lib/hide.dylib", RTLD_LAZY);
	
	BOOL DeletedSomething = NO;
	
	if(libHandle != NULL) 
	{
		BOOL (*LibHideIcon)(NSString* Plist) = dlsym(libHandle, "HideIcon");
		if(LibHideIcon != NULL)
		{
			// PlistPath is the full path to the plist like "/Applications/BossPrefs.app/Info.plist"
			DeletedSomething = LibHideIcon(PlistPath);
		}
	}
	
	if(libHandle != NULL) dlclose(libHandle);
	
	return DeletedSomething;
}

//*************************************************************************************************
// UnHideIcon - Removes a hidden icon from the plist. Returns TRUE  if something was done, FALSE ir not.
//*************************************************************************************************
BOOL UnHideIcon(NSString* Path)
{
	BOOL SomethingDone = NO;
	void* libHandle = dlopen("/usr/lib/hide.dylib", RTLD_LAZY);
	
	if(libHandle != NULL) 
	{
		BOOL (* LibUnHideIcon)(NSString* Plist) = dlsym(libHandle, "UnHideIcon");
		if(LibUnHideIcon != NULL)
		{
			SomethingDone = LibUnHideIcon(Path);
		}
	}
	if(libHandle != NULL) dlclose(libHandle);
	
	return SomethingDone;
}

