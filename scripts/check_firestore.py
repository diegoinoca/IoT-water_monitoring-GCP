#!/usr/bin/env python3
"""
Script para verificar datos en Firestore
"""
from google.cloud import firestore

def check_firestore():
    db = firestore.Client(project='potent-odyssey-480320-k4')
    
    # Listar colecciones
    collections = list(db.collections())
    print(f"\n📁 Colecciones en Firestore: {len(collections)}\n")
    
    if not collections:
        print("  ⚠️  No hay colecciones en Firestore")
        return
    
    for collection in collections:
        print(f"📂 Colección: {collection.id}")
        
        # Contar documentos
        docs = list(collection.limit(10).stream())
        print(f"   Total documentos (primeros 10): {len(docs)}")
        
        # Mostrar documentos de ejemplo
        for i, doc in enumerate(docs[:3], 1):
            print(f"\n   📄 Documento {i}: {doc.id}")
            data = doc.to_dict()
            for key, value in data.items():
                if isinstance(value, dict):
                    print(f"      {key}: {str(value)[:100]}...")
                else:
                    print(f"      {key}: {value}")
        
        print("\n" + "="*80 + "\n")

if __name__ == '__main__':
    check_firestore()
