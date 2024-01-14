//
//  ViewController.m
//  KTVHTTPCacheDemo
//
//  Created by Single on 2017/8/10.
//  Copyright © 2017年 Single. All rights reserved.
//

#import "ViewController.h"
#import "MediaViewController.h"
#import "MediaItem.h"
#import "MediaCell.h"
#import <KTVHTTPCache/KTVHTTPCache.h>

@interface ViewController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, weak) IBOutlet UITableView *tableView;
@property (nonatomic, strong) NSArray<MediaItem *> *items;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [self setupHTTPCache];
    });
    [self setupItems];
}

- (void)setupHTTPCache
{
    [KTVHTTPCache logSetConsoleLogEnable:YES];
    NSError *error = nil;
    [KTVHTTPCache proxyStart:&error];
    if (error) {
        NSLog(@"Proxy Start Failure, %@", error);
    } else {
        NSLog(@"Proxy Start Success");
    }
    [KTVHTTPCache encodeSetURLConverter:^NSURL *(NSURL *URL) {
        NSLog(@"URL Filter reviced URL : %@", URL);
        return URL;
    }];
    [KTVHTTPCache downloadSetUnacceptableContentTypeDisposer:^BOOL(NSURL *URL, NSString *contentType) {
        NSLog(@"Unsupport Content-Type Filter reviced URL : %@, %@", URL, contentType);
        return NO;
    }];
}

- (void)setupItems
{
    MediaItem *item1 = [[MediaItem alloc] initWithTitle:@"萧亚轩 - 冲动"
                                              URLString:@"http://aliuwmp3.changba.com/userdata/video/45F6BD5E445E4C029C33DC5901307461.mp4"];
    MediaItem *item2 = [[MediaItem alloc] initWithTitle:@"张惠妹 - 你是爱我的"
                                              URLString:@"http://aliuwmp3.changba.com/userdata/video/3B1DDE764577E0529C33DC5901307461.mp4"];
    MediaItem *item3 = [[MediaItem alloc] initWithTitle:@"hush! - 都是你害的"
                                              URLString:@"http://qiniuuwmp3.changba.com/941946870.mp4"];
    MediaItem *item4 = [[MediaItem alloc] initWithTitle:@"张学友 - 我真的受伤了"
                                              URLString:@"http://lzaiuw.changba.com/userdata/video/940071102.mp4"];
    self.items = @[item1, item2, item3, item4];
    [self.tableView reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    MediaItem *item = [self.items objectAtIndex:indexPath.row];
    MediaCell *cell = [tableView dequeueReusableCellWithIdentifier:@"MediaCell"];
    [cell configureWithTitle:item.title];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    MediaItem *item = [self.items objectAtIndex:indexPath.row];
    NSString *URLString = [item.URLString stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSURL *URL = [KTVHTTPCache proxyURLWithOriginalURL:[NSURL URLWithString:URLString]];
    MediaViewController *vc = [[MediaViewController alloc] initWithURLString:URL.absoluteString];
    [self presentViewController:vc animated:YES completion:nil];
}


@end

/*
 Metadata:
     major_brand     : isom
     minor_version   : 512
     compatible_brands: isomiso2avc1mp41
     creation_time   : 2017-08-08T07:28:36.000000Z
     encoder         : Lavf57.25.100
   Duration: 00:05:29.63, start: 0.000000, bitrate: 594 kb/s
   Stream #0:0[0x1](und): Video: h264 (High) (avc1 / 0x31637661), yuv420p(progressive), 480x480, 457 kb/s, 30 fps, 30 tbr, 15360 tbn (default)
     Metadata:
       creation_time   : 2017-08-08T07:28:36.000000Z
       handler_name    : VideoHandler
       vendor_id       : [0][0][0][0]
   Stream #0:1[0x2](und): Audio: aac (LC) (mp4a / 0x6134706D), 44100 Hz, stereo, fltp, 128 kb/s (default)
     Metadata:
       creation_time   : 2017-08-08T07:28:36.000000Z
       handler_name    : SoundHandler
       vendor_id       : [0][0][0][0]
     "streams": [
         {
             "index": 0,
             "codec_name": "h264",
             "codec_long_name": "H.264 / AVC / MPEG-4 AVC / MPEG-4 part 10",
             "profile": "High",
             "codec_type": "video",
             "codec_tag_string": "avc1",
             "codec_tag": "0x31637661",
             "width": 480,
             "height": 480,
             "coded_width": 480,
             "coded_height": 480,
             "closed_captions": 0,
             "film_grain": 0,
             "has_b_frames": 2,
             "pix_fmt": "yuv420p",
             "level": 30,
             "chroma_location": "left",
             "field_order": "progressive",
             "refs": 1,
             "is_avc": "true",
             "nal_length_size": "4",
             "id": "0x1",
             "r_frame_rate": "30/1",
             "avg_frame_rate": "30/1",
             "time_base": "1/15360",
             "start_pts": 0,
             "start_time": "0.000000",
             "duration_ts": 5062656,
             "duration": "329.600000",
             "bit_rate": "457532",
             "bits_per_raw_sample": "8",
             "nb_frames": "9888",
             "extradata_size": 40,
             "disposition": {
                 "default": 1,
                 "dub": 0,
                 "original": 0,
                 "comment": 0,
                 "lyrics": 0,
                 "karaoke": 0,
                 "forced": 0,
                 "hearing_impaired": 0,
                 "visual_impaired": 0,
                 "clean_effects": 0,
                 "attached_pic": 0,
                 "timed_thumbnails": 0,
                 "captions": 0,
                 "descriptions": 0,
                 "metadata": 0,
                 "dependent": 0,
                 "still_image": 0
             },
             "tags": {
                 "creation_time": "2017-08-08T07:28:36.000000Z",
                 "language": "und",
                 "handler_name": "VideoHandler",
                 "vendor_id": "[0][0][0][0]"
             }
         },
         {
             "index": 1,
             "codec_name": "aac",
             "codec_long_name": "AAC (Advanced Audio Coding)",
             "profile": "LC",
             "codec_type": "audio",
             "codec_tag_string": "mp4a",
             "codec_tag": "0x6134706d",
             "sample_fmt": "fltp",
             "sample_rate": "44100",
             "channels": 2,
             "channel_layout": "stereo",
             "bits_per_sample": 0,
             "initial_padding": 0,
             "id": "0x2",
             "r_frame_rate": "0/0",
             "avg_frame_rate": "0/0",
             "time_base": "1/44100",
             "start_pts": 0,
             "start_time": "0.000000",
             "duration_ts": 14536683,
             "duration": "329.630000",
             "bit_rate": "128004",
             "nb_frames": "14197",
             "extradata_size": 2,
             "disposition": {
                 "default": 1,
                 "dub": 0,
                 "original": 0,
                 "comment": 0,
                 "lyrics": 0,
                 "karaoke": 0,
                 "forced": 0,
                 "hearing_impaired": 0,
                 "visual_impaired": 0,
                 "clean_effects": 0,
                 "attached_pic": 0,
                 "timed_thumbnails": 0,
                 "captions": 0,
                 "descriptions": 0,
                 "metadata": 0,
                 "dependent": 0,
                 "still_image": 0
             },
             "tags": {
                 "creation_time": "2017-08-08T07:28:36.000000Z",
                 "language": "und",
                 "handler_name": "SoundHandler",
                 "vendor_id": "[0][0][0][0]"
             }
         }
     ],
     "format": {
         "filename": "/Users/justinlau/Downloads/1.mp4",
         "nb_streams": 2,
         "nb_programs": 0,
         "format_name": "mov,mp4,m4a,3gp,3g2,mj2",
         "format_long_name": "QuickTime / MOV",
         "start_time": "0.000000",
         "duration": "329.630000",
         "size": "24483470",
         "bit_rate": "594204",
         "probe_score": 100,
         "tags": {
             "major_brand": "isom",
             "minor_version": "512",
             "compatible_brands": "isomiso2avc1mp41",
             "creation_time": "2017-08-08T07:28:36.000000Z",
             "encoder": "Lavf57.25.100"
         }
     }
 }
 */
