Shader "Unlit/SDF_Drawer"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _PreComputedHeightTex ("Precomputed_Height", 2D) = "white" {}
        _PrevNormalTex ("Prev_Normal", 2D) = "white" {}
        _NewNormalTex ("New_Normal", 2D) = "white" {}
        _PrevHeightTex ("Prev_Height", 2D) = "white" {}
        _NewHeightTex ("New_Height", 2D) = "white" {}
        _Sharpness ("Sharpness", Range(0.000,5)) = 0.1
        _OffsetDist ("OffsetDist", Range(0.001,0.1)) = 0.01
        
        _Scale_X("X_Scale", float) = 12.8
        _Scale_Y("Y_Scale", float) = 7.2
        _Offset_X("X_Offset", float) = 0
        _Offset_Y("Y_Offset", float) = 0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        // 0. Create HeightMap
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;                
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float4 _ptA;
            float4 _ptB;
            float _Sharpness;
            float _Scale_X;
            float _Scale_Y;
            float _Offset_X;
            float _Offset_Y;

            // my methods
            float sdSegment( float2 p, float2 a, float2 b)
            {
                float2 pa = p-a;
                float2 ba = b-a;
                float h = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 );
                return length( pa - ba*h );
            }

            float3 sdNormal(float sdf)
            {
                float3 normal;
                normal.x = ddx(sdf);
                normal.y = ddy(sdf);
                normal.z = sqrt(1 - normal.x*normal.x - normal.y * normal.y); // Reconstruct z component to get a unit normal.
                return normal;
            }

            
            

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                
                
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // sample the texture
                fixed4 col = tex2D(_MainTex, i.uv);

                //get sdf value
                float2 uv = (1-i.uv) * float2(_Scale_X,_Scale_Y) + float2(_Offset_X,_Offset_Y);
                float sdf = sdSegment(uv,_ptA.xy, _ptB.xy);
                sdf = smoothstep(0,_Sharpness,sdf);
                
                return col * sdf;
            }
            ENDCG
        }
        
        // 1. Create NormalMap
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            sampler2D _PreComputedHeightTex;
            float4 _MainTex_TexelSize;
            float4 _MainTex_ST;
            float4 _ptA;
            float4 _ptB;
            int _Width;
            int _Height;
            float _Sharpness;
            float _OffsetDist;

            // my methods
            float sdSegment( float2 p, float2 a, float2 b )
            {
                float2 pa = p-a;
                float2 ba = b-a;
                float h = clamp( dot(pa,ba)/dot(ba,ba), 0.0, 1.0 );
                return length( pa - ba*h );
            }

            float3 sdNormal(float sdf)
            {
                float3 normal;
                normal.x = ddx(sdf);
                normal.y = ddy(sdf);
                normal.z = saturate( sqrt(1 - normal.x*normal.x - normal.y * normal.y)); // Reconstruct z component to get a unit normal.
                return normal;
            }

            float3 FindNormal(sampler2D tex, float2 uv, float u)
            {
                    //u is one uint size, ie 1.0/texture size
                float2 offsets[4];
                offsets[0] = uv + float2(-u, 0);
                offsets[1] = uv + float2(u, 0);
                offsets[2] = uv + float2(0, -u);
                offsets[3] = uv + float2(0, u);
               
                float hts[4];
                for(int i = 0; i < 4; i++)
                {
                    hts[i] = tex2D(tex, offsets[i]).x;
                }
               
                float2 _step = float2(1.0, 0.0);
               
                float3 va = normalize( float3(_step.xy, hts[1]-hts[0]) );
                float3 vb = normalize( float3(_step.yx, hts[3]-hts[2]) );
               
               return cross(va,vb).rgb; //you may not need to swizzle the normal
               
            }

            float getHeight(float2 uv)
            {
                return tex2D(_MainTex, uv).r;
            }


            float4 bumpFromDepth(float2 uv, float2 resolution, float scale, float height)
            {
                float2 step = 1. / resolution;
    
                float2 dxy = height - float2(
                getHeight(uv + float2(step.x, 0.)), 
                getHeight(uv + float2(0., step.y))
            );
    
            return float4(normalize(float3(dxy * scale / step, 1.)), height);
        }
            

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                //float3 normal = FindNormal(_MainTex, i.uv, _MainTex_TexelSize.x);
                float4 height = tex2D(_PreComputedHeightTex, i.uv);
                float sdf = height.x;
                //float sdf = sdSegment(i.uv,_ptA.xy, _ptB.xy);
                //sdf = smoothstep(0,_Sharpness,sdf);
                //float2 uv = i.uv/float2(_Width,_Height);
                return float4( bumpFromDepth(i.uv,float2(_Width,_Height),0.1,sdf).rgb*0.5+0.5,1);

            }
            ENDCG
        }
        
        // 2. Smooth Minimum of normals
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            sampler2D _PrevNormalTex;
            sampler2D _NewNormalTex;
            float4 _MainTex_ST;


            //-------extra

            // polynomial smooth min (k = 0.1);
            float smin( float a, float b, float k )
            {
                float h = max( k-abs(a-b), 0.0 )/k;
                return min( a, b ) - h*h*k*(1.0/4.0);
            }

            float3 smin( float3 a, float3 b, float3 k )
            {
                float h = max( k-abs(a-b), 0.0 )/k;
                return min( a, b ) - h*h*k*(1.0/4.0);
            }
            

            //-------main
            
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float3 n1 = tex2D(_PrevNormalTex, i.uv).rgb;
                float3 n2 = tex2D(_NewNormalTex, i.uv).rgb;

                return float4(min(n1,n2),1);
                return float4(smin(n1,n2,float3(0.1,0.1,0.1)),1);
            }
            ENDCG
        }
        
        // 3. Smooth Minimum of normals
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            sampler2D _PrevHeightTex;
            sampler2D _NewHeightTex;
            float4 _MainTex_ST;


            //-------extra

            // polynomial smooth min (k = 0.1);
            float smin( float a, float b, float k )
            {
                float h = max( k-abs(a-b), 0.0 )/k;
                return min( a, b ) - h*h*k*(1.0/4.0);
            }

            float3 smin( float3 a, float3 b, float3 k )
            {
                float h = max( k-abs(a-b), 0.0 )/k;
                return min( a, b ) - h*h*k*(1.0/4.0);
            }
            

            //-------main
            
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float3 n1 = tex2D(_PrevHeightTex, i.uv).rgb;
                float3 n2 = tex2D(_NewHeightTex, i.uv).rgb;

                return float4(min(n1,n2),1);
                //return float4(smin(n1,n2,float3(0.1,0.1,0.1)),1);
            }
            ENDCG
        }
        
         // 4. Empty values
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;


            //-------main
            
            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                return float4(1,1,1,1);
            }
            ENDCG
        }
    }
}
