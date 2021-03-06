#import "DOOMBSP.H"
#import "Storage.h"
#import <ctype.h>

typedef struct
{
	char		identification[4];		// should be IWAD
	int		numlumps;
	int		infotableofs;
} wadinfo_t;


typedef struct
{
	int		filepos;
	int		size;
	char		name[8];
} lumpinfo_t;


@implementation Wadfile

//=============================================================================

/*
============
=
= initFromFile:
=
============
*/

- initFromFile: (char const *)path
{
	wadinfo_t	wad;
	lumpinfo_t	*lumps;
	int			i;
	
	pathname = (char *)malloc(strlen(path)+1);
	strcpy (pathname, path);
	dirty = NO;
	handle = open (pathname, O_RDWR, 0666);
	if (handle== -1)
	{
		[self free];
		return nil;
	}
//
// read in the header
//
	read (handle, &wad, sizeof(wad));
	if (strncmp(wad.identification,"IWAD",4))
	{
		close (handle);
		[self free];
		return nil;
	}
	wad.numlumps = LONG (wad.numlumps);
	wad.infotableofs = LONG (wad.infotableofs);
	
//
// read in the lumpinfo
//
	lseek (handle, wad.infotableofs, L_SET);
	info = [[CompatibleStorage alloc] initCount: wad.numlumps elementSize: sizeof(lumpinfo_t) description: ""];
	lumps = (lumpinfo_t *)[info elementAt: 0];
	
	read (handle, lumps, wad.numlumps*sizeof(lumpinfo_t));
	for (i=0 ; i<wad.numlumps ; i++, lumps++)
	{
		lumps->filepos = LONG (lumps->filepos);
		lumps->size = LONG (lumps->size);
	}
	
	return self;
}


/*
============
=
= initNew:
=
============
*/

- initNew: (char const *)path
{
	wadinfo_t	wad;

	pathname = (char *)malloc(strlen(path)+1);
	strcpy (pathname, path);
	info = [[CompatibleStorage alloc] initCount: 0 elementSize: sizeof(lumpinfo_t) description: ""];
	dirty = YES;
	handle = open (pathname, O_CREAT | O_TRUNC | O_RDWR, 0666);
	if (handle== -1)
		return nil;
// leave space for wad header
	write (handle, &wad, sizeof(wad));
	
	return self;
}

-close
{
	close (handle);
	return self;
}

-free
{
	close (handle);
	[info dealloc];
	free (pathname);
	[super dealloc];
	return self;
}

//=============================================================================

- (int)numLumps
{
	return [info count];
}

- (int)lumpsize: (int)lump
{
	lumpinfo_t	*inf;
	inf = (__bridge lumpinfo_t *)[info elementAt: lump];
	return inf->size;
}

- (int)lumpstart: (int)lump
{
	lumpinfo_t	*inf;
	inf = (lumpinfo_t *)[info elementAt: lump];
	return inf->filepos;
}

- (char const *)lumpname: (int)lump
{
	lumpinfo_t	*inf;
	inf = (lumpinfo_t *)[info elementAt: lump];
	return inf->name;
}

/*
================
=
= lumpNamed:
=
================
*/

- (int)lumpNamed: (char const *)name
{
	lumpinfo_t	*inf;
	int			i, count;
	char			name8[9];
	int			v1,v2;

// make the name into two integers for easy compares

	memset(name8,0,9);
	if (strlen(name) < 9)
		strncpy (name8,name,9);
	for (i=0 ; i<9 ; i++)
		name8[i] = toupper(name8[i]);	// case insensitive

	v1 = *(int *)name8;
	v2 = *(int *)&name8[4];


// scan backwards so patch lump files take precedence

	count = [info count];
	for (i=count-1 ; i>=0 ; i--)
	{
		inf = (lumpinfo_t *)[info elementAt: i];
		if ( *(int *)inf->name == v1 && *(int *)&inf->name[4] == v2)
			return i;
	}
	return  -1;
}

/*
================
=
= loadLump:
=
================
*/

- (void *)loadLump: (int)lump
{
	lumpinfo_t	*inf;
	byte			*buf;
	
	inf = (lumpinfo_t *)[info elementAt: lump];
	buf = (byte *)malloc (inf->size);
	
	lseek (handle, inf->filepos, L_SET);
	read (handle, buf, inf->size);
	
	return buf;
}

- (void *)loadLumpNamed: (char const *)name
{
	return [self loadLump:[self lumpNamed: name]];
}

//============================================================================

/*
================
=
= addName:data:size:
=
================
*/

- addName: (char const *)name data: (void *)data size: (int)size
{
	int		i;
	lumpinfo_t	newlump;
	
	dirty = YES;
	memset (newlump.name,0,sizeof(newlump.name));
	strncpy (newlump.name, name, 8);
	for (i=0 ; i<8 ; i++)
		newlump.name[i] = toupper(newlump.name[i]);
	newlump.filepos = lseek(handle,0, L_XTND);
	newlump.size = size;
	[info addElement: &newlump];
	
	write (handle, data, size);
	
	return self;
}


/*
================
=
= writeDirectory:
=
	char		identification[4];		// should be IWAD
	int		numlumps;
	int		infotableofs;
================
*/

- writeDirectory
{
	wadinfo_t	wad;
	int			i,count;
	lumpinfo_t	*inf;
	
//
// write the directory
//
	count = [info count];
	inf = (lumpinfo_t *)[info elementAt:0];
	for (i=0 ; i<count ; i++)
	{
		inf[i].filepos = LONG (inf[i].filepos);
		inf[i].size = LONG (inf[i].size);
	}
	wad.infotableofs = LONG (lseek(handle,0, L_XTND));
	write (handle, inf, count*sizeof(lumpinfo_t));
	for (i=0 ; i<count ; i++)
	{
		inf[i].filepos = LONG (inf[i].filepos);
		inf[i].size = LONG (inf[i].size);
	}
	
//
// write the header
//
	strncpy (wad.identification, "IWAD",4);
	wad.numlumps = LONG ([info count]);
	lseek (handle, 0, L_SET);
	write (handle, &wad, sizeof(wad));
	
	return self;
}

@end

