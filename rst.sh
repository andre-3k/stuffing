#!/bin/bash
#!/usr/bin/python

export PATH=$PATH:/usr/local/bin/:/usr/bin

# Safety feature: exit script if error is returned, or if variables not set.
# Exit if a pipeline results in an error.
set -ue
set -o pipefail


## Function Declarations ##
# Collect and state all Instance ID(s)
instance_ids() {
       	for instance_id in $instance_list; do

       					echo "Instance ID is $instance_id"
       		region="us-east-1"

       	done
}

# Clone AMI Image from Instance ID(s)
create_image() {
       	for instance_id in $instance_list; do

       					echo "Creating AMI from $instance_id"

       					# Build Image Name(s) and Descriptor(s)
       		image_description="$(hostname)-image-$instance_id-2017-11-7"
       		image_name="$(hostname)-image--$instance_id-2017-11-7"

       					# Create Duplicate Image from Instance ID
       		image_ids=$(aws ec2 create-image --instance-id $instance_id --name $image_name --description $image_description --output text)
       		echo "New image is $image_ids"
       					#cat georgie.txt
       					# Confirm creation of new Image by querying for Image ID
       		#aws ec2 describe-images --image-ids $image_ids --query 'Images[*].{ID:ImageId}'
       					#image_state=aws ec2 describe-images --image-ids $image_ids --query 'Images[*].{ID:State}' --output text

       	done
}

# Spin new Instance from Cloned AMI Image(s)
run_instance() {
       	for image_id in $image_ids; do
       					while state=$(aws ec2 describe-images --image-ids $image_id --query 'Images[*].{ID:State}' --output text); test "$state" = "pending"; do
                  echo "Image $image_id not ready to clone, current state is $state"
       		        echo "Re-Attempting Clone in 30 Seconds"
       		        sleep 30
       		       done
       		 # Create 1 New Instance== Size T2.Nano , Same Key Pair, Same Security Group. Built into same Subnet
                       	aws ec2 run-instances --image-id $image_ids --count 1 --instance-type t2.nano --key-name rst_kpair --security-group-ids sg-03c90971 --subnet-id subnet-dee93b95
                until state=$(aws ec2 describe-images --image-ids $image_id --query 'Images[*].{ID:State}' --output text); test "$state" = "available"; do
                  echo "Image $image_id is READY!!!!"
                  echo "current state is $state"
       				  done
        done
}

# Stop instance and make sure Instance is either in RUNNING State or STOPPED State, NOT "Stopping"
stop_instance_id() {
       	for instance_id in $instance_list; do

       					echo "STOPPING $instance_id"
       		region="us-east-1"

       					# Stop Instance ID
       		aws ec2 stop-instances --instance-ids $instance_id

       					# Check if instance is being stopped
       		if state=$(aws ec2 describe-instances --instance-ids $instance_id --output text --query 'Reservations[*].Instances[*].State.Name'); test "$state" = "stopping"; then
       			echo "## Instance $instance_id is $state ##"

       					# If instance is not stopping collect state
       					else echo "$instance_id IS $state"

       		fi

       	done
}

# Collect Volume ID(s)
volume_ids() {
       	for volume_id in $volume_list; do

       					echo "Volume ID is $volume_id"

       				done
}

# Snapshot Volumes of Instance ID where State == Stopped
snapshot_volume() {
       	for instance_id in $instance_list; do

       		# If State is stopping, wait
       		while state=$(aws ec2 describe-instances --instance-ids $instance_id --output text --query 'Reservations[*].Instances[*].State.Name'); test "$state" = "stopping"; do
       		 echo "$instance_id is still $state"
       	         echo "Re-Attempting Clone in 30 Seconds"
               	 sleep 30


       		done

       		# If State is stopped, collect Volume ID(s) and Snapshot Quiesced EBS Root Drive
       		until state=$(aws ec2 describe-instances --instance-ids $instance_id --output text --query 'Reservations[*].Instances[*].State.Name'); test "$state" = "stopped"; do

       			for volume_id in $volume_list; do

       				echo "Prepairing to Snapshot Instance $instance_id Volume $volume_id"
       				#echo "Volume ID is $volume_id"

       				# Get the attched device name to add to the description so we can easily tell which volume this is.
       				device_name=$(aws ec2 describe-volumes --region $region --output=text --volume-ids $volume_id --query 'Volumes[0].{Devices:Attachments[0].Device}')

       				# Take a snapshot of the current volume, and capture the resulting snapshot ID
       				snapshot_description="$(hostname)-$device_name-backup-2017-11-7"

       				# Create snapshot of
       				snapshot_id=$(aws ec2 create-snapshot --region $region --output=text --description $snapshot_description --volume-id $volume_id --query SnapshotId)
       				echo "New snapshot is $snapshot_id"

       				# Add a "CreatedBy:AutomatedBackup" tag to the resulting snapshot.
       				# Why? To keep track of what/who created the snap (or for purging later).
       				aws ec2 create-tags --region $region --resource $snapshot_id --tags Key=CreatedBy,Value=AutomatedBackup
       			done
       		done
       	done
}

snapshot_volumes() {
       	for volume_id in $volume_list; do
       		#echo "Volume ID is $volume_id"

       		# Get the attched device name to add to the description so we can easily tell which volume this is.
       		device_name=$(aws ec2 describe-volumes --region $region --output=text --volume-ids $volume_id --query 'Volumes[0].{Devices:Attachments[0].Device}')

       		# Take a snapshot of the current volume, and capture the resulting snapshot ID
       		snapshot_description="$(hostname)-$device_name-backup-2017-11-7"

       		snapshot_id=$(aws ec2 create-snapshot --region $region --output=text --description $snapshot_description --volume-id $volume_id --query SnapshotId)
       		echo "New snapshot is $snapshot_id"

       		# Add a "CreatedBy:AutomatedBackup" tag to the resulting snapshot.
       		# Why? To keep track of what/who created the snap (or for purging later).
       		aws ec2 create-tags --region $region --resource $snapshot_id --tags Key=CreatedBy,Value=AutomatedBackup
       	done
}

## Run Functions##

instance_id=$(python colector.py | grep "i-")
#correct_size=python COLEctor.py | grep "t2.nano"
instance_list=$(aws ec2 describe-instances --instance-id $instance_id --query 'Reservations[*].Instances[*].[InstanceId]' --output text)
instance_ids
create_image
run_instance
stop_instance_id
volume_list=$(aws ec2 describe-volumes --region $region --filters Name=attachment.instance-id,Values=$instance_id --query Volumes[].VolumeId --output text)
volume_ids
snapshot_volume
#snapshot_volumes
