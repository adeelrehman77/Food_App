from dj_rest_auth.serializers import UserDetailsSerializer as BaseUserDetailsSerializer
from rest_framework import serializers

class UserDetailsSerializer(BaseUserDetailsSerializer):
    groups = serializers.SlugRelatedField(
        many=True,
        read_only=True,
        slug_field='name'
    )
    
    class Meta(BaseUserDetailsSerializer.Meta):
        fields = BaseUserDetailsSerializer.Meta.fields + ('groups',)
