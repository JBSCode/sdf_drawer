using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using Unity.Mathematics;

public class PathDrawer : MonoBehaviour
{
    [Header("Input Elements")]
    public Transform endEffector;
    public BoxCollider box;

    [Header("Controls")] 
    [Tooltip("Defines the maximum distance between the current and previous end effector position in order to renew the texture maps")]
    public float _DistanceThreshold;

    [Header("Graphics")]
    public RenderTexture heightMap;
    public RenderTexture CombinedHeightMap;
    public RenderTexture normalMap;
    public Material sdf_mat;


    private int _width;
    private int _height;
    private RenderTexture start;
    private RenderTexture PrevHeightMap;
    private float3 b_min;
    private float3 b_max;
    private float3 pos_prev;
    private float3 pos_now;
    private float4 c_pos;
    private float4 prev_c_pos;
    private float distance;

    private bool firstNormal;
    
    
    // Start is called before the first frame update
    void Start()
    {
        firstNormal = true;
        
        // initialize bounds
        b_min = box.bounds.min;
        b_max = box.bounds.max;
        
        // extract and assign width/height
        _width = heightMap.width;
        _height = heightMap.height;
        
        sdf_mat.SetInt("_Width",_width);
        sdf_mat.SetInt("_Height",_height);
        
        // assign first position
        pos_prev = endEffector.position;
        pos_now = pos_prev;
        
        
        // create first rt
        start = new RenderTexture(_width,_height,0,RenderTextureFormat.ARGBFloat)
        {
            anisoLevel        = 0,
            enableRandomWrite = true,
            antiAliasing      = 1,
            filterMode        = FilterMode.Trilinear
        };
        
        PrevHeightMap =  new RenderTexture(_width,_height,0,RenderTextureFormat.ARGBFloat)
        {
            anisoLevel        = 0,
            enableRandomWrite = true,
            antiAliasing      = 1,
            filterMode        = FilterMode.Trilinear
        };
        
        Graphics.Blit(start,start,sdf_mat,4);
        //Graphics.Blit(initialNormal,prevNormalMap);
        DrawPath();
        
    }

    // Update is called once per frame
    void Update()
    {
        pos_now = endEffector.position;
        if (!pos_now.Equals(pos_prev))
        {
            distance = math.length(pos_now - pos_prev);
            if (distance >= _DistanceThreshold)
            {
                DrawPath();
                pos_prev = pos_now;
            }
        }
        
    }

    private float2 Remap(float3 pos)
    {
        return math.remap(b_min.xz, b_max.xz, new float2(1,1), new float2(0,0), pos.xz);
    }

    
    private void DrawPath()
    {
        c_pos = new float4(pos_now.xz,0,1);
        prev_c_pos = new float4(pos_prev.xz,0,1);
        
        // assign point values to shader
        sdf_mat.SetVector("_ptA",c_pos);
        sdf_mat.SetVector("_ptB",prev_c_pos);
        
        // calculate height
        Graphics.Blit(start,heightMap,sdf_mat,0);
        
        // combine height textures
        CombinePathHistory();
        
        //
        Graphics.Blit(CombinedHeightMap,normalMap,sdf_mat,1);
        
        
        CombinePathHistory();
        
    }

    private void CombinePathHistory()
    {
        // test if have calculated the normals once
        if (firstNormal)
        {
            Graphics.Blit(heightMap,PrevHeightMap);
            firstNormal = false;
            //return;
        }
        
        sdf_mat.SetTexture("_PrevHeightTex",PrevHeightMap);
        sdf_mat.SetTexture("_NewHeightTex",heightMap);
        
        Graphics.Blit(PrevHeightMap,CombinedHeightMap,sdf_mat,3);

        Graphics.Blit(CombinedHeightMap,PrevHeightMap);
    }
}
