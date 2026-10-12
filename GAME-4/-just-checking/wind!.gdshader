shader_type spatial;

// Wind settings jo aap Inspector se change kar sakte hain
uniform float wind_speed = 2.0;
uniform float wind_strength = 0.2;
uniform float wind_scale = 1.0;

void vertex() {
    // Ye line ensure karti hai ke bush ki jadd (root) zameen par hi rahe aur sirf upar wala hissa hile
    float strength = (1.0 - VERTEX.y) * wind_strength;
    
    // Time aur vertex position ka use kar ke noise simulation create karna
    float wind_cycle = TIME * wind_speed + (VERTEX.x + VERTEX.z) * wind_scale;
    
    // Vertex ko X aur Z axis par move karna
    VERTEX.x += sin(wind_cycle) * strength;
    VERTEX.z += cos(wind_cycle * 0.5) * strength;
}
