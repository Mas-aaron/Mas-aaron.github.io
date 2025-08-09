from django.db import migrations

def create_groups(apps, schema_editor):
    Group = apps.get_model('auth', 'Group')
    Group.objects.get_or_create(name='Rider')
    Group.objects.get_or_create(name='Restaurant')

class Migration(migrations.Migration):

    dependencies = [
        ('api', '0023_merge_20250803_1921'),
    ]

    operations = [
        migrations.RunPython(create_groups),
    ]
