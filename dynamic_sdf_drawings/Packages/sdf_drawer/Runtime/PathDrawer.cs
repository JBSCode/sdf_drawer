using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using Unity.Mathematics;

public class PathDrawer : MonoBehaviour
{
    [Header("Input Elements")]
    public Transform endEffector;
    public Transform bed;

    [Header("Controls")] 
    [Tooltip("Defines the maximum distance between the current and previous end effector position in order to renew the texture maps")]
    public float _DistanceThreshold;
    public float _HeightThreshold;
    public float scale_multiplier;
    

    [Header("Graphics")]
    public RenderTexture heightMap;
    public RenderTexture CombinedHeightMap;
    public RenderTexture normalMap;
    public Material sdf_mat;


    private int _width;
    private int _height;
    private RenderTexture start;
    private RenderTexture PrevHeightMap;
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
        
        // extract and assign width/height
        _width = heightMap.width;
        _height = heightMap.height;

        var offset_x = bed.transform.position.x - ((bed.localScale.x * scale_multiplier) / 2);
        var offset_y = bed.transform.position.z - ((bed.localScale.z * scale_multiplier) / 2);
        
        sdf_mat.SetFloat("_Scale_X",bed.localScale.x * scale_multiplier);
        sdf_mat.SetFloat("_Scale_Y",bed.localScale.z * scale_multiplier);
        
        sdf_mat.SetFloat("_Offset_X",offset_x);
        sdf_mat.SetFloat("_Offset_Y",offset_y);
        
        sdf_mat.SetInt("_Width",_width);
        sdf_mat.SetInt("_Height",_height);
        
        // assign first position if the end effector is below yhe allowed threshold
        InitEndEffector();
        
        
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
        Debug.Log(pos_now.y);
        
        if (pos_now.y > _HeightThreshold) InitEndEffector();

        
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
        sdf_mat.SetTexture("_PreComputedHeightTex",CombinedHeightMap);
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

    private void InitEndEffector()
    {
        pos_prev = endEffector.position;
        pos_now = pos_prev;
    }
}
