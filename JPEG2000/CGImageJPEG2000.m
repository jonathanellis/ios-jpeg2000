// Adapted from https://gist.github.com/nielsbot/1861465#file-uiimagejpeg2000-m-L25

#import <CoreGraphics/CoreGraphics.h>
#import <objc/runtime.h>

#import "openjpeg.h"

CGImageRef CGImageCreateWithJPEG2000Image( opj_image_t * image )
{
	long w = image->comps[0].w ;
	long h = image->comps[0].h ;
	assert( w > 0 && h > 0 ) ;

	CGColorSpaceRef cs = NULL ;
	BOOL hasAlpha = NO ;
	
	if ( image->numcomps == 1 )
	{
		cs = CGColorSpaceCreateDeviceGray() ;
	}
	else
	{
		// only support 3 (RGB) or 4 (RGBA) component images
		assert( image->numcomps == 3 || image->numcomps == 4 ) ;
		
		hasAlpha = image->numcomps == 4 ;
		cs = CGColorSpaceCreateDeviceRGB() ;
	}
	assert( cs ) ;
	
	for( int index=0; index < image->numcomps; ++index )
	{
		assert( image->comps[ index ].prec == 8 &&
					w == image->comps[index].w 
					&& h == image->comps[index].h ) ;
	}

	size_t bitmapNumBytes = w * h * 4;//image->numcomps ;
	CFMutableDataRef bitmapCFData = CFDataCreateMutable( kCFAllocatorDefault, 0 ) ;
	CFDataSetLength( bitmapCFData, bitmapNumBytes ) ;
	
	assert( bitmapCFData ) ;
	CGBitmapInfo bitmapInfo = kCGBitmapByteOrder32Big ;
	
	if ( image->numcomps == 1 )
	{
		uint8_t * p = (uint8_t*)CFDataGetMutableBytePtr( bitmapCFData ) ;
		uint32_t * s = (uint32_t*)image->comps[0].data ;
		
		for( int index=0, count = w * h; index < count; ++index )
		{
			*p = *s ;
			++p ;
			++s ;
			
		}
	}
	else
	{
		uint8_t * p = (uint8_t*)CFDataGetMutableBytePtr( bitmapCFData ) ;

		uint32_t * r = (uint32_t *)image->comps[0].data ;
		uint32_t * g = (uint32_t *)image->comps[1].data ;
		uint32_t * b = (uint32_t *)image->comps[2].data ;

		if ( hasAlpha )
		{
			bitmapInfo |= kCGImageAlphaPremultipliedLast ;
			uint32_t * a = (uint32_t *)image->comps[3].data ;
			
			for( int index=0, count = w * h; index < count; ++index )
			{
				*p++ = *r++ ;
				*p++ = *g++ ;
				*p++ = *b++ ;
				*p++ = *a++ ;				
			}
			
		}
		else
		{
			bitmapInfo |= kCGImageAlphaNoneSkipLast ;
			for( int index=0, count = w * h; index < count; ++index )
			{
				*p++ = *r++ ;
				*p++ = *g++ ;
				*p++ = *b++ ;
				*p++ = 0xFF ;
			}
		}
	}
	
	CGDataProviderRef dataProvider = CGDataProviderCreateWithCFData( bitmapCFData ) ;
	if ( bitmapCFData ) { CFRelease( bitmapCFData ) ; }
	
	assert( dataProvider ) ;
			
	int bpc = image->comps[0].prec ;	// bits per component
	int bpp = image->numcomps == 1 ? bpc : (4 * bpc) ;		// bits per pixel
	int bpr = bpp * w / 8 ;				// bytes per row
	
	CGImageRef cgImage = CGImageCreate(w, h, bpc, bpp, bpr, cs, bitmapInfo, dataProvider, NULL, false, kCGRenderingIntentDefault ) ;

	CGDataProviderRelease( dataProvider ) ;
	CGColorSpaceRelease( cs ) ;
	
	assert( cgImage ) ;
	
	return cgImage ;
}
