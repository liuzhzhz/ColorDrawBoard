//
//  TSHBoard.h
//  TuShou
//
//  Created by liu on 16/3/14.
//  Copyright © 2016年 tujiao. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TSHDrawModel.h"
@class TSHDrawCotent;
@class TSHChannel;
@class TSHTopic;

//typedef NS_ENUM(NSInteger, TSHDrawingStatus)
//{
//    TSHDrawingStatusBegin,//准备绘制
//    TSHDrawingStatusMove,//正在绘制
//    TSHDrawingStatusEnd//结束绘制
//};

//typedef NS_ENUM(NSInteger, TSHPlaySource)
//{
//    /**播放本地资源*/
//    TSHPlaySourceLocalSource,
//    /**播放网络资源－需先将modles数组传入*/
//    TSHPlaySourceNetSource
//};

//typedef void(^drawStatusBlock)(TSHDrawingStatus drawingStatus, TSHDrawModel *model);
typedef void(^boardImageBlock)(UIImage *boardBackImage);
typedef void(^completePlayDrawing)();
//绘画进度回调
typedef void(^drawingProgressBlock)(CGFloat sclae,NSInteger drawID);

@interface TSHBoard : UIView

//暂停状态
@property (assign, nonatomic) BOOL isPause;

/**
 *  背景透明度
 */

@property (strong, nonatomic) NSNumber *bgAlpha;

/**
 *  缓存图
 */
@property (strong, nonatomic) UIImage *cachedImage;

@property (strong, nonatomic) NSArray *models ;
/**
 *  画笔宽度
 */
@property (assign, nonatomic) CGFloat lineWidth;
/**
 *  画笔颜色
 */
@property (strong, nonatomic) UIColor *lineColor;
/**
 *  背景色
 */
@property (strong, nonatomic) UIColor *bgColor ;

/**
 *  画板背景
 */
@property (copy, nonatomic) NSString *bgImageStr;

@property (strong, nonatomic) UIImage *bgImg;

/**设置绘画回调*/
- (void)setDrawingProgressBlock:(drawingProgressBlock)cb;

/**改变绘制进度后继续绘制*/
- (void)sliderValueChanged:(CGFloat)scale drawID:(NSInteger)drawID;

/**本地数据加载*/
- (void)drawLocalData;

/**
 *  绘制缩略图
 */
- (void)drawThumbnail;

/**缩放结束处理*/
- (void)zoomEnd;

/**
 *  清屏
 */
- (void)clearAll;
/**
 *  撤销
 */
- (void)goBack;
/**
 *  恢复
 */
- (void)goForward;
/**
 *  使用橡皮檫
 */
- (void)eraser;
/**
 *  取消使用橡皮擦
 */
- (void)cancleEraser;

/**删除上传文件*/
- (void)removeLocalHistoryJsonFile;

/**
 *  将上传文件的操作添加进队列
 *
 *
 */
- (void)addUploadFileOperationBlock:(completePlayDrawing)voidBlock;

/**
 *  暂停或继续绘制
 *
 *
 */
- (void)pauseOrContinueDrawing;

/**暂停绘画*/
- (void)pauseDrawing;

/**继续绘画*/
- (void)continueDrawing;

/**设置暂停或继续绘画 结束时回调*/
- (void)setCompletePlayDrawing:(completePlayDrawing)block;

/**背景和画笔颜色互换*/
- (void)changeColor:(UIView*)bgView;

/**橡皮线宽 缩放*/
- (void)changeEraserLineWidth:(CGFloat)scale;

/**画板是否有有效的绘制路径*/
- (BOOL)isExistActualPath;

/**
 *  保存到相册,先判断isExistActualPath
 */
- (void)saveCurrentImageToAlbumWithUserName:(NSString *)userName;

/**获取当前绘制的图片*/
- (UIImage *)getCurrentImage;

/**获取当前绘制的路径Json数据*/
- (NSString *)getCurrentDrawingPathJson;

/**
 *  获取完整的接涂绘制路径
 *
 *  @param jsonUrl:原作的json数据路径
 */
//- (NSData *)getCompleteForkDrawingJsonWith:(NSString *)jsonUrl;

/**获取用户需要保存的绘画数据*/
- (NSData *)getCurrentDrawingJsonFile;

/**获取用户需要保存的绘画数据*/
- (NSArray *)getNeedSaveModels;

/**保存到本地*/
- (BOOL)saveDrawContentToLocal:(TSHDrawCotent*)drawCt chanel:(TSHChannel*)chanel forkImg:(UIImage*)forkImage topic:(TSHTopic*)topic isASNewDraft:(BOOL)isNewDraft tempDraftImage:(UIImage *)tempImg drawStyle:(NSNumber *)drawStyle boardType:(NSNumber *)type;

/**获取用户需要保存的Json路径*/
- (NSURL*)getCurrentJsonFileUrl;

/**
 *  获取绘制状态
 *
 *  @param stautsBlock 内含状态值
 */
//- (void)drawingStatus:(drawStatusBlock)stautsBlock;

///**移除所有改View上的手势*/
//- (void)removeAllGestureRecognizers;

/**
 *  根据点的集合绘制
 *
 *  @param points    ["{x,y}"...]
 *  @param lineColor 颜色
 *  @param lineWidth 线宽
 *
 *  @return YES -> 绘制完成  反之
 */
- (BOOL)drawWithPoints:(TSHDrawModel *)model;
/**
 *  获取背景
 */
- (void)getChangeBoardImage:(boardImageBlock)boardImage;

/**
 *  默认回放－－播放本地资源
 */
- (void)drawPlayBack;

/**
 *  回放－－播放网络资源
 */
- (void)drawPlayBackNetSource:(NSArray*)data ID:(NSInteger)ID;

/**回放*/
//- (void)drawPlayBackWith:(TSHPlaySource)source;

/**停止播放*/
- (void)stopPlayDrawing;

- (void)clearDataExpextUploadData;
@end

#pragma mark - TSHPath
typedef enum pathDrawType {
    pathDrawTypeStart,
    pathDrawTypeMove,
    pathDrawTypeEnd
}pathDrawType;

@interface TSHPath : NSObject

@property (strong, nonatomic) UIColor *pathColor;//画笔颜色
@property (strong, nonatomic) UIBezierPath *bezierPath;

@property (assign, nonatomic) BOOL isEraser;//橡皮擦
@property (assign, nonatomic) CGPoint startPoint;
@property (assign, nonatomic) CGPoint endPoint;
@property (assign, nonatomic) CGPoint controlPoint1;
@property (assign, nonatomic) CGPoint controlPoint2;

+ (void)drawBezierPoint:(CGPoint)point withWidth:(CGFloat)width;

+ (instancetype)pathToPoint:(CGPoint)beginPoint pathWidth:(CGFloat)pathWidth;//初始化对象
//- (void)pathLineToPoint:(CGPoint)movePoint;//画
- (void)pathLineToPoint:(CGPoint)movePoint startPoint:(CGPoint)startPoint;
- (void)drawPathLine:(pathDrawType)type;
- (void)drawPath;//绘制
@end

#pragma mark TSHCAShapeLayer

//@interface TSHCAShapeLayer: CAShapeLayer
//
//@property (strong, nonatomic) NSArray * data ;
//@property (strong, nonatomic) NSMutableArray * paths ;
//@property (strong, nonatomic) UIBezierPath * myBezierPath ;
//@property (strong, nonatomic) UIImage *cachedImage;
//
//@end

