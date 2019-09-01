VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
  Persistable = 0  'NotPersistable
  DataBindingBehavior = 0  'vbNone
  DataSourceBehavior  = 0  'vbNone
  MTSTransactionMode  = 0  'NotAnMTSObject
END
Attribute VB_Name = "clsTextureManager"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = False
Option Explicit
 
Private Const BYTES_PER_MB          As Long = 1048576
Private Const DEFAULT_MEMORY_TO_USE As Long = 64 ' In MB
Private Const HASH_TABLE_SIZE       As Long = 337

Private Type SURFACE_ENTRY_DYN
    filename As Integer
    UltimoAcceso As Long
    Texture As Direct3DTexture8
    size As Long
    texture_width As Integer
    texture_height As Integer
End Type
 
Private Type HashNode
    surfaceCount As Integer
    SurfaceEntry() As SURFACE_ENTRY_DYN
End Type

Private TexList(HASH_TABLE_SIZE - 1) As HashNode
Private DirectD3D                    As D3DX8
 
' Parra was here (;
Private mGraphicsNumber              As Long
Private mCurrentMemoryBytes          As Long
Private mMaxMemoryBytes              As Long
 
Private Sub Class_Terminate()

    '**************************************************************
    'Author: Juan Mart�n Sotuyo Dodero
    'Last Modify Date: 5/04/2005
    '
    '**************************************************************
    Dim i As Long
    Dim j As Long
   
    'Destroy every surface in memory
    For i = 0 To HASH_TABLE_SIZE - 1

        With TexList(i)

            For j = 1 To .surfaceCount
                Set .SurfaceEntry(j).Texture = Nothing
            Next j
           
            'Destroy the arrays
            Erase .SurfaceEntry

        End With

    Next i

End Sub
 
Public Property Get Surface(ByVal fileIndex As Long) As Direct3DTexture8

    '**************************************************************
    'Author: Juan Mart�n Sotuyo Dodero
    'Last Modify Date: 3/06/2006
    'Used to return a texture
    '**************************************************************
    
End Property
 
Public Function GetTexture(ByVal filename As Integer, _
                           ByRef TextureWidth As Long, _
                           ByRef TextureHeight As Long) As Direct3DTexture8

    If filename = 0 Then
        Debug.Print "0 GRH ATTEMPT TO BE LOADED"
        Exit Function

    End If
 
    Dim i As Long

    ' Search the index on the list
    With TexList(filename Mod HASH_TABLE_SIZE)

        For i = 1 To .surfaceCount

            If .SurfaceEntry(i).filename = filename Then
                .SurfaceEntry(i).UltimoAcceso = GetTickCount
                TextureWidth = .SurfaceEntry(i).texture_width
                TextureHeight = .SurfaceEntry(i).texture_height
                Set GetTexture = .SurfaceEntry(i).Texture
                Exit Function

            End If

        Next i

    End With
 
    'Not in memory, load it!
    Set GetTexture = CrearGrafico(filename, TextureWidth, TextureHeight)

End Function
 
Public Sub Initialize(ByRef DD As D3DX8, ByVal graphicPath As String, Optional ByVal maxMemoryUsageInMb As Long = -1)
    '**************************************************************
    'Author: Juan Mart�n Sotuyo Dodero
    'Last Modify Date: 5/04/2005
    '
    '**************************************************************
   
    'Seteamos el objeto
    Set DirectD3D = DD
   
    ' Parra is back (;
    mGraphicsNumber = 0
    mCurrentMemoryBytes = 0
    mMaxMemoryBytes = maxMemoryUsageInMb * BYTES_PER_MB

End Sub

Private Function CrearGrafico(ByVal Archivo As Integer, _
                              ByRef TextureWidth As Long, _
                              ByRef TextureHeight As Long) As Direct3DTexture8

    On Error GoTo ErrHandler

    Dim surface_desc As D3DSURFACE_DESC
    Dim texture_info As D3DXIMAGE_INFO
    Dim Index        As Integer
    Dim buffer()     As Byte
    
    Index = Archivo Mod HASH_TABLE_SIZE

    With TexList(Index)
    
        .surfaceCount = .surfaceCount + 1
        ReDim Preserve .SurfaceEntry(1 To .surfaceCount) As SURFACE_ENTRY_DYN

        With .SurfaceEntry(.surfaceCount)
            'Nombre
            .filename = Archivo
           
            'Ultimo acceso
            .UltimoAcceso = timeGetTime

            #If Compression = 1 Then
            
                'Obtenemos el .bmp del archivo en Graphics.AO
                Call modCompression.Get_Image(Game.path(Graficos), CStr(Archivo), buffer())
                
                'Seteamos la textura.
                Set .Texture = DirectD3D.CreateTextureFromFileInMemoryEx(DirectDevice, buffer(0), UBound(buffer()) + 1, D3DX_DEFAULT, D3DX_DEFAULT, 0, 0, D3DFMT_A8R8G8B8, _
                                                                         D3DPOOL_MANAGED, D3DX_FILTER_POINT, D3DX_FILTER_NONE, &HFF000000, texture_info, ByVal 0)
                Erase buffer
                
            #Else
                
                If FileExist(Graphic & ".bmp", vbNormal) Then
                    Set .Texture = DirectD3D.CreateTextureFromFileEx(DirectDevice, Graphic & ".BMP", D3DX_DEFAULT, D3DX_DEFAULT, 0, 0, D3DFMT_A8R8G8B8, _
                                                                     D3DPOOL_MANAGED, D3DX_FILTER_NONE, D3DX_FILTER_NONE, &HFF000000, ByVal 0, ByVal 0)
                
                ElseIf FileExist(Graphic & ".png", vbNormal) Then
                    Set .Texture = DirectD3D.CreateTextureFromFileEx(DirectDevice, Graphic & ".PNG", D3DX_DEFAULT, D3DX_DEFAULT, 0, 0, D3DFMT_A8R8G8B8, _
                                                                     D3DPOOL_MANAGED, D3DX_FILTER_NONE, D3DX_FILTER_NONE, &HFF000000, ByVal 0, ByVal 0)
                
                Else
                    MsgBox "No se ha podido cargar el grafico con indice: " & fileIndex
                    Call CloseClient
                
                End If
                
            #End If
 
            Call .Texture.GetLevelDesc(0, surface_desc)
            
            .texture_width = texture_info.Width
            .texture_height = texture_info.Height
            .size = surface_desc.size
            
            TextureWidth = .texture_width
            TextureHeight = .texture_height
            
            Set CrearGrafico = .Texture

            ' Parra is back (;
            mGraphicsNumber = mGraphicsNumber + 1
            mCurrentMemoryBytes = mCurrentMemoryBytes + surface_desc.size

        End With

    End With
   
    Do While mGraphicsNumber > 0 And mCurrentMemoryBytes > mMaxMemoryBytes

        If Not RemoveLRU() Then
            Exit Do

        End If

    Loop
    
    Exit Function
    
ErrHandler:
    Debug.Print "ERROR AL CARGAR EL GRAFICO> " & Archivo & ".bmp"

End Function

Private Function RemoveLRU() As Boolean

    '**************************************************************
    'Author: Juan Mart?n Sotuyo Dodero
    'Last Modify Date: 3/06/2006
    'Removes the Least Recently Used surface to make some room for new ones
    '**************************************************************
    Dim LRUi         As Long
    Dim LRUj         As Long
    Dim LRUtime      As Long
    Dim i            As Long
    Dim j            As Long
    Dim surface_desc As D3DSURFACE_DESC
   
    LRUtime = GetTickCount
   
    'Check out through the whole list for the least recently used
    For i = 0 To HASH_TABLE_SIZE - 1

        With TexList(i)

            For j = 1 To .surfaceCount

                If LRUtime > .SurfaceEntry(j).UltimoAcceso Then
                    LRUi = i
                    LRUj = j
                    LRUtime = .SurfaceEntry(j).UltimoAcceso

                End If

            Next j

        End With

    Next i
   
    'Retrieve the surface desc
    Call TexList(LRUi).SurfaceEntry(LRUj).Texture.GetLevelDesc(0, surface_desc)
   
    ' Parra is back (;
    mCurrentMemoryBytes = mCurrentMemoryBytes - surface_desc.size
   
    'Remove it
    Set TexList(LRUi).SurfaceEntry(LRUj).Texture = Nothing
    TexList(LRUi).SurfaceEntry(LRUj).filename = 0
   
    ' Parra is back (;
    mGraphicsNumber = mGraphicsNumber - 1
   
    'Move back the list (if necessary)
    If LRUj Then
        RemoveLRU = True
       
        With TexList(LRUi)

            For j = LRUj To .surfaceCount - 1
                .SurfaceEntry(j) = .SurfaceEntry(j + 1)
            Next j
           
            .surfaceCount = .surfaceCount - 1

            If .surfaceCount Then
                ReDim Preserve .SurfaceEntry(1 To .surfaceCount) As SURFACE_ENTRY_DYN
            Else
                Erase .SurfaceEntry

            End If

        End With

    End If

End Function
