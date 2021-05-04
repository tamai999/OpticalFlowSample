#include <metal_stdlib>
using namespace metal;

#include <CoreImage/CoreImage.h>

// 色を付けるベクトルの長さ
#define minLen      200.0
#define maxLen      300.0
// 二等辺三角形の頂角
#define tipAngle    30.0
#define tipAngleRadians (tipAngle * M_PI_F / 180.0)
// 格子のサイズ
#define cellSize    30.0

// ベクトルの長さで色の濃さを決める
half4 makeColor(half2 vector) {
    // ベクトルが短い場合色を暗くする
    half4 color = half4(1.0);
    half vectorLength = length(vector);
    color.rgb *= clamp((vectorLength - minLen) / (maxLen - minLen), 0.0, 1.0);
    
    return color;
}

half makeTriangleAlpha(half2 position, half theta) {
    half result = 1.0;
    
    // 二等辺三角形の底辺よりした部分を削る
    half threshold = position.x * cos(theta) - position.y * sin(theta);
    float bottomOffset = cellSize * 0.5 * cos(tipAngleRadians);

    half alpha = step(1.0, threshold + bottomOffset);
    result *= alpha;

    // 二等辺三角形の左側を削る
    float sideAngle = (M_PI_F - tipAngleRadians) / 2.0;
    float sideOffset = 0.5 * sin(tipAngleRadians / 2.0) * cellSize;

    threshold = position.x * cos(theta - sideAngle) - position.y * sin(theta - sideAngle);
    alpha = 1.0 - step(1.0 ,threshold - sideOffset);
    result *= alpha;

    // 二等辺三角形の右側を削る
    threshold = position.x * cos(theta + sideAngle) - position.y * sin(theta + sideAngle);
    alpha = 1.0 - step(1.0 ,threshold - sideOffset);
    result *= alpha;
    
    return result;
}

extern "C" {
    namespace coreimage {
        half4 flowView(sampler_h image, destination dest)
        {
            // 描画先の座標
            float2 destCoord = dest.coord();
            
            // 一辺が size の格子と考えて、描画先の座標が格子の枠の中のどの位置(position)になるのかを計算
            float2 cellCenter = floor((destCoord / cellSize) + 0.5) * cellSize;
            half2 positionInCell = half2(destCoord - cellCenter);
            
            // size の格子の中のベクトル・色を統一化。
            float2 transform = image.transform(cellCenter);
            half2 cellCenterVector = image.sample(transform).xy;
            half4 color = makeColor(cellCenterVector);
            half theta = atan2(cellCenterVector.y, cellCenterVector.x);

            // 三角形になるように色を削る
            color.rgb *= makeTriangleAlpha(positionInCell, theta);
            
            return half4(color);
        }
    }
}
